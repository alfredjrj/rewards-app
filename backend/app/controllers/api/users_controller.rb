class Api::UsersController < AuthenticationController
  def me
    render json: { id: current_user.id, email: current_user.email }
  end
end
