class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate!(auth_options)
    sign_in(resource_name, resource)
    render json: {
      message: "Signed in successfully",
      user: user_json(resource)
    }, status: :ok
  end

  def destroy
    signed_in = signed_in?(resource_name)
    sign_out
    if signed_in
      render json: { message: "Signed out successfully" }, status: :ok
    else
      render json: { message: "No active session" }, status: :ok
    end
  end

  private

  def user_json(user)
    { id: user.id, email: user.email }
  end
end
