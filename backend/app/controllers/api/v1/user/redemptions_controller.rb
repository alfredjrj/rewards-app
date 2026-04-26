class Api::V1::User::RedemptionsController < AuthenticationController
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
        data: {
          id: result.redemption.id,
          reward_id: result.redemption.reward_id,
          points_cost_snapshot: result.redemption.points_cost_snapshot,
          status: result.redemption.status,
          points_balance: result.points_balance
        }
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
