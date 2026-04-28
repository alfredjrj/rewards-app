class Api::V1::User::RedemptionsController < AuthenticationController
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 50

  def index
    authorize :redemption, :index?

    scope = policy_scope(User::Redemption, policy_scope_class: RedemptionPolicy::Scope)
              .includes(:reward)
              .order(created_at: :desc, id: :desc)
    scope = RedemptionHistoryQuery.new(scope, params).call

    pagy_request = Pagy::Request.new(
      request: request,
      limit: DEFAULT_PER_PAGE,
      max_limit: MAX_PER_PAGE,
      limit_key: "per_page"
    )
    pagy_obj, paginated_redemptions = Pagy::OffsetPaginator.paginate(scope, request: pagy_request)

    render json: ::Api::V1::User::RedemptionHistorySerializer::Collection
      .call(redemptions: paginated_redemptions)
      .merge(meta: ::Api::V1::PaginationMetaSerializer.call(pagy: pagy_obj))
  end

  def create
    reward = ::Reward.find(redemption_params[:reward_id])
    authorize :redemption, :create?

    idempotency_key = request.headers["Idempotency-Key"].presence || SecureRandom.uuid
    # Mirror Sidekiq intent in Redis so GET /points can subtract pending before the ledger debit
    # runs (see User::Redemptions::PendingPoints).
    did_reserve = User::Redemptions::PendingPoints.reserve!(
      user_id: current_user.id,
      request_id: idempotency_key,
      points: reward.points_cost
    )
    begin
      # Demo / interview only: enqueue processing 1s later so pending points (Redis) stay visible
      # before the job runs—not how you’d ship production latency; use perform_async instead.
      User::Redemptions::ProcessJob.perform_in(2.second, current_user.id, reward.id, idempotency_key)
    rescue StandardError
      User::Redemptions::PendingPoints.release!(user_id: current_user.id, request_id: idempotency_key) if did_reserve
      raise
    end

    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: idempotency_key,
      reward_id: reward.id,
      status: "processing"
    ), status: :accepted
  end

  def show
    authorize :redemption, :index?

    request_id = params[:id].to_s

    # Polling fallback for async redemptions:
    # ProcessJob writes request-scoped status to cache and broadcasts via Action Cable.
    # We read cache first for fast completion/failure lookup, then fall back to DB
    # (idempotency_key match) when cache is missing/expired.
    cached_status = Rails.cache.read(cache_key_for(request_id))
    if cached_status.present?
      payload = cached_status.to_h.stringify_keys
      render json: ::Api::V1::User::RedemptionSerializer::Status.call(
        request_id: payload["request_id"] || request_id,
        status: payload["status"],
        reward_id: payload["reward_id"],
        error: payload["error"]
      )
      return
    end

    redemption = current_user.redemptions.find_by(idempotency_key: request_id)
    if redemption
      render json: ::Api::V1::User::RedemptionSerializer::Status.call(
        request_id: request_id,
        status: "completed",
        redemption: redemption
      )
      return
    end

    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: request_id,
      status: "processing"
    )
  end

  private
  def redemption_params
    params.require(:redemption).permit(:reward_id)
  end

  def cache_key_for(request_id)
    "redemption_request_status:user:#{current_user.id}:#{request_id}"
  end
end
