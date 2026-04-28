class Api::V1::User::PointsController < AuthenticationController
  # points_balance is ledger-only; pending points come from DB rows with status=processing.
  def show
    authorize current_user, :show?

    points_balance = current_user
      .point_transactions
      .order(created_at: :desc, id: :desc)
      .pick(:running_balance) || 0

    points_pending_redemption = current_user
      .redemptions
      .where(status: "processing")
      .sum(:points_cost_snapshot)
    points_available = [ points_balance - points_pending_redemption, 0 ].max

    render json: ::Api::V1::User::PointsBalanceSerializer.call(
      points_balance: points_balance,
      points_pending_redemption: points_pending_redemption,
      points_available: points_available
    )
  end
end
