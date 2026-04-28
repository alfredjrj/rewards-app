class AuthenticationController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  after_action :verify_pundit_authorization!, unless: :devise_controller?
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

  def verify_pundit_authorization!
    return unless current_user

    verify_authorized
    verify_policy_scoped if action_name == "index"
  end
end
