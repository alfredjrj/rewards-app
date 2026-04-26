class Api::V1::UsersController < AuthenticationController
  def show
    authorize current_user, :show?

    render json: {
      id: current_user.id,
      email: current_user.email
    }
  end
end
