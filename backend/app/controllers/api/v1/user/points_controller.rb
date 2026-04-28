class Api::V1::User::PointsController < AuthenticationController
  # points_balance is ledger-only; pending points come from DB rows with status=processing.
  def show
    authorize current_user, :show?
    balance = User::Points::AvailableBalance.call(user: current_user)

    render json: ::Api::V1::User::PointsBalanceSerializer.call(
      points_balance: balance[:points_balance],
      points_pending_redemption: balance[:points_pending_redemption],
      points_available: balance[:points_available]
    )
  end
end
