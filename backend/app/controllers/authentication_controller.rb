class AuthenticationController < ApplicationController
  include Pundit::Authorization

  before_action :authenticate_user!
  before_action :verify_csrf_token!, unless: :safe_http_method?
  after_action :verify_pundit_authorization!, unless: :devise_controller?
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActionController::ParameterMissing, with: :parameter_missing

  private

  def pundit_user
    current_user
  end

  def authenticate_user!
    return if current_user

    render json: { error: "Not authenticated" }, status: :unauthorized
  end

  def verify_csrf_token!
    return unless current_user
    return if valid_authenticity_token?(session, request.headers["X-CSRF-Token"].to_s)

    skip_authorization
    render json: {
      error: {
        code: "invalid_csrf_token",
        message: "X-CSRF-Token is missing or invalid"
      }
    }, status: :forbidden
  end

  def user_not_authorized
    render json: {
      error: {
        code: "forbidden",
        message: "Not authorized"
      }
    }, status: :forbidden
  end

  def record_not_found
    render json: {
      error: {
        code: "not_found",
        message: "Resource not found"
      }
    }, status: :not_found
  end

  def parameter_missing(exception)
    render json: {
      error: {
        code: "parameter_missing",
        message: exception.message
      }
    }, status: :bad_request
  end

  def verify_pundit_authorization!
    return unless current_user

    verify_authorized
    verify_policy_scoped if action_name == "index"
  end

  def safe_http_method?
    request.get? || request.head? || request.options?
  end
end
