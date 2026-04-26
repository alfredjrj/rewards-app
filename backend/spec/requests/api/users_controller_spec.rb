require "rails_helper"

RSpec.describe "Api::V1::UsersController", type: :request do
  describe "GET /api/v1/user" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/user"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns user profile fields" do
        get "/api/v1/user"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to eq(
          "id" => user.id,
          "email" => user.email
        )
      end
    end
  end
end
