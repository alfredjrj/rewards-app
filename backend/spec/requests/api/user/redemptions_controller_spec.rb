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

      it "filters by points range using filter[points][gte/lte]" do
        reward = create(:reward)
        create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 100)
        create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 250)
        create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 500)

        get "/api/v1/user/redemptions", params: { filter: { points: { gte: 150, lte: 300 } } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].length).to eq(1)
        expect(body["data"].first["points_cost_snapshot"]).to eq(250)
      end

      it "filters by status" do
        reward = create(:reward)
        create(:user_redemption, user: user, reward: reward, status: "completed")
        create(:user_redemption, user: user, reward: reward, status: "cancelled")

        get "/api/v1/user/redemptions", params: { filter: { status: "cancelled" } }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].map { |row| row["status"] }.uniq).to eq([ "cancelled" ])
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

      it "enqueues async redemption processing and returns processing state" do
        key = "406625f1-81c1-43e4-9e74-377e4c6ff31c"
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)
        allow(User::Redemptions::PendingPoints).to receive(:reserve!).and_return(true)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key }

        expect(User::Redemptions::PendingPoints).to have_received(:reserve!).with(
          user_id: user.id,
          request_id: key,
          points: reward.points_cost
        )

        expect(User::Redemptions::ProcessJob).to have_received(:perform_in).with(
          1.second,
          user.id,
          reward.id,
          key
        )

        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body["data"]).to eq(
          "request_id" => key,
          "reward_id" => reward.id,
          "status" => "processing"
        )
      end
    end
  end

  describe "GET /api/v1/user/redemptions/:id" do
    context "when signed in" do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it "returns processing when request is still pending" do
        get "/api/v1/user/redemptions/pending-123"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          "data" => {
            "request_id" => "pending-123",
            "status" => "processing"
          }
        )
      end

      it "returns completed when redemption exists for request id" do
        reward = create(:reward)
        redemption = create(
          :user_redemption,
          user: user,
          reward: reward,
          idempotency_key: "done-123"
        )

        get "/api/v1/user/redemptions/done-123"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          "data" => {
            "request_id" => "done-123",
            "id" => redemption.id,
            "reward_id" => reward.id,
            "points_cost_snapshot" => reward.points_cost,
            "status" => "completed"
          }
        )
      end
    end
  end
end
