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
    result = ::User::Redemptions::Create.call(
      user: current_user,
      reward: reward,
      idempotency_key: idempotency_key
    )

    if result.success?
      render json: {
        data: ::Api::V1::User::RedemptionSerializer.call(
          redemption: result.redemption,
          points_balance: result.points_balance
        )
      }, status: :created
      return
    end

    status = case result.error[:code]
    when "insufficient_balance", "reward_unavailable"
      :unprocessable_entity
    else
      :unprocessable_entity
    end

    render json: { error: result.error }, status: status
  end

  private
  def redemption_params
    params.require(:redemption).permit(:reward_id)
  end
end
