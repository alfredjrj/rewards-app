class Api::V1::User::PointsController < AuthenticationController
  def show
    authorize current_user, :show?

    points_balance = current_user
      .point_transactions
      .order(created_at: :desc, id: :desc)
      .pick(:running_balance) || 0

    render json: { data: { points_balance: points_balance } }
  end
end
