class Api::V1::User::RedemptionsController < AuthenticationController
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 50
  before_action :set_create_idempotency_key, :load_and_render_existing_redemption, only: :create

  def index
    authorize User::Redemption, :index?

    scope = policy_scope(User::Redemption)
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

    enqueue_result = User::Redemptions::PlaceCreditHoldAndEnqueue.call(
      user: current_user,
      reward: @reward,
      idempotency_key: @idempotency_key
    )
    unless enqueue_result.success?
      error_status = enqueue_result.error&.dig(:code) == "enqueue_unavailable" ? :service_unavailable : :unprocessable_entity
      render json: { error: enqueue_result.error }, status: error_status
      return
    end

    result_status = enqueue_result.redemption&.status || "processing"
    http_status = result_status == "processing" ? :accepted : :ok

    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: @idempotency_key,
      reward_id: enqueue_result.redemption&.reward_id || @reward.id,
      status: result_status
    ), status: http_status
  end

  def show
    request_id = params[:id].to_s

    # Polling fallback for async redemptions:
    # ProcessJob writes request-scoped status to cache and broadcasts via Action Cable.
    # We read cache first for fast completion/failure lookup, then fall back to DB
    # (idempotency_key match) when cache is missing/expired.
    cached_status = User::Redemptions::StatusPublisher.read(
      user_id: current_user.id,
      request_id: request_id
    )
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
      authorize redemption, :show?
      render json: ::Api::V1::User::RedemptionSerializer::Status.call(
        request_id: request_id,
        status: redemption.status,
        redemption: redemption
      )
      return
    end

    skip_authorization
    render json: {
      error: {
        code: "not_found",
        message: "No redemption found for request id"
      }
    }, status: :not_found
  end

  private
  def redemption_params
    params.require(:redemption).permit(:reward_id)
  end

  def existing_redemption_for(idempotency_key)
    current_user.redemptions.find_by(idempotency_key: idempotency_key)
  end

  def set_create_idempotency_key
    result = Idempotency::KeyValidator.call(
      raw_header_value: request.headers["Idempotency-Key"]
    )
    if result.valid?
      @idempotency_key = result.key
      return
    end

    skip_authorization
    render json: { error: result.error }, status: :bad_request
  end

  def load_and_render_existing_redemption
    @existing_redemption = existing_redemption_for(@idempotency_key)
    return unless @existing_redemption

    authorize @existing_redemption, :show?
    http_status = @existing_redemption.status == "processing" ? :accepted : :ok
    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: @idempotency_key,
      status: @existing_redemption.status,
      redemption: @existing_redemption
    ), status: http_status
  end
end
