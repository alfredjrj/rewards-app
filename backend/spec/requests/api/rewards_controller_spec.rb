require "rails_helper"

RSpec.describe "Api::V1::RewardsController", type: :request do
  describe "GET /api/v1/rewards" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/rewards"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns success" do
        get "/api/v1/rewards"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end
end
