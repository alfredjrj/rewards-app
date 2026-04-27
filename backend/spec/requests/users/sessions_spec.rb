require "rails_helper"

RSpec.describe "User sessions", type: :request do
  describe "POST /users/sign_in" do
    it "returns Devise-specific message when credentials are invalid" do
      user = create(:user)
      post "/users/sign_in",
        params: { user: { email: user.email, password: "not-the-password" } },
        headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
        as: :json

      expect(response).to have_http_status(:unauthorized)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq(
        I18n.t("devise.failure.invalid", authentication_keys: User.human_attribute_name(:email))
      )
    end

    it "returns 200 with user payload when credentials are valid" do
      user = create(:user)
      post "/users/sign_in",
        params: { user: { email: user.email, password: "password123" } },
        headers: { "Accept" => "application/json", "Content-Type" => "application/json" },
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["user"]).to include("id" => user.id, "email" => user.email)
    end
  end
end
