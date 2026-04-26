class AuthenticationController < ApplicationController
  before_action :authenticate_user!

  private

  def authenticate_user!
    return if current_user

    render json: { error: "Not authenticated" }, status: :unauthorized
  end
end
