require "rails_helper"

RSpec.describe "User registrations", type: :request do
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

  describe "POST /users" do
    it "returns 201 with user payload when signup is valid" do
      post "/users",
        params: { user: { email: "new-user@example.com", password: "password123", password_confirmation: "password123" } },
        headers: json_headers,
        as: :json

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["user"]).to include("email" => "new-user@example.com")
      expect(json.dig("meta", "csrf_token")).to be_present
    end

    it "returns 429 after too many signup requests from same ip" do
      5.times do |index|
        post "/users",
          params: {
            user: {
              email: "signup-rate-#{index}@example.com",
              password: "password123",
              password_confirmation: "password123"
            }
          },
          headers: json_headers.merge("REMOTE_ADDR" => "203.0.113.77"),
          as: :json
        expect(response).to have_http_status(:created)
      end

      post "/users",
        params: {
          user: {
            email: "signup-rate-over-limit@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        },
        headers: json_headers.merge("REMOTE_ADDR" => "203.0.113.77"),
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
