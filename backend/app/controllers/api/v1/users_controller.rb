class Api::V1::UsersController < AuthenticationController
  def show
    authorize current_user, :show?

    render json: ::Api::V1::User::ProfileSerializer.call(user: current_user)
  end
end
