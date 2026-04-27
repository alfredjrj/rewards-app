require "rails_helper"

RSpec.describe "Api::V1::User::RedemptionsController", type: :request do
  describe "GET /api/v1/user/redemptions" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/user/redemptions"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }
      let(:other_user) { create(:user) }

      before do
        sign_in user
      end

      it "returns the current user's redemptions in descending order" do
        reward_a = create(:reward, title: "Coffee Voucher")
        reward_b = create(:reward, title: "VIP Pass")

        older = create(
          :user_redemption,
          user: user,
          reward: reward_a,
          points_cost_snapshot: 100,
          created_at: 2.days.ago
        )
        newer = create(
          :user_redemption,
          user: user,
          reward: reward_b,
          points_cost_snapshot: 300,
          created_at: 1.day.ago
        )
        create(:user_redemption, user: other_user, reward: reward_a)

        get "/api/v1/user/redemptions"

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |row| row["id"] }).to eq([ newer.id, older.id ])
        expect(body["data"].map { |row| row["reward_title"] }).to eq([ "VIP Pass", "Coffee Voucher" ])
        expect(body["meta"]).to include(
          "page" => 1,
          "per_page" => 10,
          "total_count" => 2,
          "total_pages" => 1
        )
      end

      it "supports page and per_page params" do
        reward = create(:reward)
        3.times { create(:user_redemption, user: user, reward: reward) }

        get "/api/v1/user/redemptions", params: { page: 2, per_page: 1 }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(1)
        expect(body["meta"]).to include(
          "page" => 2,
          "per_page" => 1,
          "total_count" => 3,
          "total_pages" => 3
        )
      end
    end
  end

  describe "POST /api/v1/user/redemptions" do
    let(:reward) { create(:reward, points_cost: 100, is_available: true) }

    context "when not signed in" do
      it "returns unauthorized" do
        post "/api/v1/user/redemptions", params: { redemption: { reward_id: reward.id } }

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq("error" => "Not authenticated")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before do
        sign_in user
        create(
          :user_point_transaction,
          user: user,
          amount: 300,
          running_balance: 300,
          kind: "earn",
          reason_code: "purchase",
          idempotency_key: "e3e1e313-a70b-4dbc-81e0-f6868503595d"
        )
      end

      it "creates a redemption and returns updated points balance" do
        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => "406625f1-81c1-43e4-9e74-377e4c6ff31c" }

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["data"]).to include(
          "reward_id" => reward.id,
          "points_cost_snapshot" => 100,
          "status" => "completed",
          "points_balance" => 200
        )
      end

      it "returns an error when balance is insufficient" do
        reward.update!(points_cost: 999)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => "cfd6fc99-884b-4c32-aa13-052f1469417d" }

        expect(response).to have_http_status(:unprocessable_entity)
        body = JSON.parse(response.body)
        expect(body["error"]["code"]).to eq("insufficient_balance")
      end
    end
  end
end
