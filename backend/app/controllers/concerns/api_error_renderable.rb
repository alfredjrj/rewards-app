module ApiErrorRenderable
  extend ActiveSupport::Concern

  private

  def render_api_error(code:, message:, status:, details: nil)
    error_payload = {
      code: code,
      message: message
    }
    error_payload[:details] = details if details.present?

    render json: { error: error_payload }, status: status
  end
end
