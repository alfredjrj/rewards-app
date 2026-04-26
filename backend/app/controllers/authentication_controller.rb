class AuthenticationController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def pundit_user
    current_user
  end

  def authenticate_user!
    return if current_user

    render json: { error: "Not authenticated" }, status: :unauthorized
  end

  def user_not_authorized
    render json: { error: "Not authorized" }, status: :forbidden
  end
end
