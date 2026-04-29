require "rails_helper"

RSpec.describe "User sessions", type: :request do
  let(:json_headers) { { "Accept" => "application/json", "Content-Type" => "application/json" } }

  around do |example|
    previous_enabled = Rack::Attack.enabled
    Rack::Attack.enabled = true
    Rack::Attack.cache.store.clear
    example.run
  ensure
    Rack::Attack.cache.store.clear
    Rack::Attack.enabled = previous_enabled
  end

  describe "POST /users/sign_in" do
    it "returns Devise-specific message when credentials are invalid" do
      user = create(:user)
      post "/users/sign_in",
        params: { user: { email: user.email, password: "not-the-password" } },
        headers: json_headers,
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
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["user"]).to include("id" => user.id, "email" => user.email)
      expect(json.dig("meta", "csrf_token")).to be_present
    end

    it "returns 429 after too many failed login attempts for same email and ip" do
      user = create(:user, email: "rate-limit@example.com")
      5.times do
        post "/users/sign_in",
          params: { user: { email: user.email, password: "wrong-password" } },
          headers: json_headers.merge("REMOTE_ADDR" => "198.51.100.10"),
          as: :json
        expect(response).to have_http_status(:unauthorized)
      end

      post "/users/sign_in",
        params: { user: { email: user.email, password: "wrong-password" } },
        headers: json_headers.merge("REMOTE_ADDR" => "198.51.100.10"),
        as: :json

      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["Retry-After"]).to be_present
      json = JSON.parse(response.body)
      expect(json).to include(
        "error" => include(
          "code" => "rate_limited",
          "message" => "Too many requests. Please try again later."
        )
      )
    end
  end
end
