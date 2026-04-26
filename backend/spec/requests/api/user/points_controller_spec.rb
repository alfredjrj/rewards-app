require "rails_helper"

RSpec.describe "Api::V1::User::PointsController", type: :request do
  describe "GET /api/v1/user/points" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/user/points"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in user }

      it "returns zero when no point transactions exist" do
        get "/api/v1/user/points"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq("data" => { "points_balance" => 0 })
      end

      it "returns the latest running balance" do
        create(
          :user_point_transaction,
          user: user,
          amount: 500,
          running_balance: 500,
          kind: "earn",
          reason_code: "signup_bonus",
          idempotency_key: "points-seed-1"
        )
        create(
          :user_point_transaction,
          user: user,
          amount: -100,
          running_balance: 400,
          kind: "redeem",
          reason_code: "reward_redemption",
          idempotency_key: "points-seed-2"
        )

        get "/api/v1/user/points"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq("data" => { "points_balance" => 400 })
      end
    end
  end
end
