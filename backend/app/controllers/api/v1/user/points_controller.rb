class Api::V1::User::PointsController < AuthenticationController
  # points_balance is ledger-only; points_pending_redemption comes from Redis (async holds).
  def show
    authorize current_user, :show?

    points_balance = current_user
      .point_transactions
      .order(created_at: :desc, id: :desc)
      .pick(:running_balance) || 0

    points_pending_redemption =
      User::Redemptions::PendingPoints.pending_total_for(user_id: current_user.id)
    points_available = [ points_balance - points_pending_redemption, 0 ].max

    render json: ::Api::V1::User::PointsBalanceSerializer.call(
      points_balance: points_balance,
      points_pending_redemption: points_pending_redemption,
      points_available: points_available
    )
  end
end
