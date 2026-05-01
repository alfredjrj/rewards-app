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

    result = if @reward.sync_fulfillment?
      User::Redemptions::Create.call(
        user: current_user,
        reward: @reward,
        idempotency_key: @idempotency_key,
        change_source_origin: "api_request",
        change_source_metadata: request_metadata.merge("fulfillment_path" => "sync")
      )
    else
      User::Redemptions::PlaceCreditHoldAndReserve.call(
        user: current_user,
        reward: @reward,
        idempotency_key: @idempotency_key,
        change_source_origin: "api_request",
        change_source_metadata: request_metadata.merge("fulfillment_path" => "async")
      )
    end

    unless result.success?
      error_code = result.error&.dig(:code)
      error_status = RedemptionErrors.transient?(error_code) ? :service_unavailable : :unprocessable_entity
      render_api_error(
        code: error_code || "redemption_failed",
        message: result.error&.dig(:message) || "Unable to process redemption",
        status: error_status,
        details: result.error&.dig(:details)
      )
      return
    end

    result_status = result.redemption&.status || "processing"
    http_status = result_status == "processing" ? :accepted : :ok

    render json: ::Api::V1::User::RedemptionSerializer::Status.call(
      request_id: @idempotency_key,
      reward_id: result.redemption&.reward_id || @reward.id,
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
    render_api_error(
      code: "not_found",
      message: "No redemption found for request id",
      status: :not_found
    )
  end

  private

  def redemption_params
    params.require(:redemption).permit(:reward_id)
  end

  def existing_redemption_for(idempotency_key)
    current_user.redemptions.find_by(idempotency_key: idempotency_key)
  end

  def request_metadata
    {
      "kind" => "http",
      "path" => request.path,
      "method" => request.method,
      "request_uuid" => request.request_id
    }.compact
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
    render_api_error(
      code: result.error&.dig(:code) || "invalid_request",
      message: result.error&.dig(:message) || "Invalid request",
      status: :bad_request,
      details: result.error&.dig(:details)
    )
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
