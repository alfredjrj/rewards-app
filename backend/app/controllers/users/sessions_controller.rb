class Users::SessionsController < Devise::SessionsController
  respond_to :json

  def create
    self.resource = warden.authenticate(auth_options)

    unless resource
      return render json: { error: devise_failure_message }, status: :unauthorized
    end

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

  def devise_failure_message
    key = warden.message

    case key
    when :locked
      I18n.t("devise.failure.locked")
    when :inactive
      I18n.t("devise.failure.inactive")
    when :timeout
      I18n.t("devise.failure.timeout")
    when :unconfirmed
      I18n.t("devise.failure.unconfirmed")
    else
      I18n.t(
        "devise.failure.invalid",
        authentication_keys: resource_class.human_attribute_name(
          resource_class.authentication_keys.first || :email
        )
      )
    end
  end

  def user_json(user)
    { id: user.id, email: user.email }
  end
end
