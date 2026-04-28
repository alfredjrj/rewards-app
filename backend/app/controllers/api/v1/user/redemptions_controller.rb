class Api::V1::User::RedemptionsController < AuthenticationController
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 50
  before_action :set_create_idempotency_key, :load_and_render_existing_redemption, only: :create

  def index
    authorize User::Redemption, :index?

    scope = policy_scope(User::Redemption, policy_scope_class: User::RedemptionPolicy::Scope)
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

    render json: ::Api::V1::User::RedemptionSerializer::Collection
      .call(redemptions: paginated_redemptions)
      .merge(meta: ::Api::V1::PaginationMetaSerializer.call(pagy: pagy_obj))
  end

  def create
    @reward = ::Reward.find(redemption_params[:reward_id])
    user_redemption = current_user.redemptions.build(reward: @reward)
    authorize user_redemption

    enqueue_result = User::Redemptions::EnqueueProcessing.call(
      user: current_user,
      reward: @reward,
      idempotency_key: @idempotency_key
    )
    unless enqueue_result.success?
      render json: { error: enqueue_result.error }, status: :unprocessable_entity
      return
    end

    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: @idempotency_key,
      reward_id: @reward.id,
      status: "processing"
    ), status: :accepted
  end

  def show
    authorize User::Redemption, :index?

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
        status: redemption.status,
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

  def existing_redemption_for(idempotency_key)
    current_user.redemptions.find_by(idempotency_key: idempotency_key)
  end

  def set_create_idempotency_key
    @idempotency_key = request.headers["Idempotency-Key"].presence
    return if @idempotency_key

    skip_authorization
    render json: {
      error: {
        code: "idempotency_key_required",
        message: "Idempotency-Key header is required"
      }
    }, status: :bad_request
  end

  def load_and_render_existing_redemption
    @existing_redemption = existing_redemption_for(@idempotency_key)
    return unless @existing_redemption

    authorize @existing_redemption
    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: @idempotency_key,
      status: @existing_redemption.status,
      redemption: @existing_redemption
    ), status: :accepted
  end
end
