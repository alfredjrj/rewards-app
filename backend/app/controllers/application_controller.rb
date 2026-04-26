class ApplicationController < ActionController::API
  include ActionController::Cookies

  before_action :authenticate_user!, unless: :devise_controller?

  def authenticate_user!
    unless current_user
      render json: { error: "Not authenticated" }, status: :unauthorized
    end
  end
end
