require "rails_helper"

RSpec.describe "Api::V1::User::RedemptionsController", type: :request do
  describe "GET /api/v1/user/redemptions" do
    context "when not signed in" do
      it "returns unauthorized" do
        get "/api/v1/user/redemptions"

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "not_authenticated",
            "message" => "Not authenticated"
          }
        )
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
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "not_authenticated",
            "message" => "Not authenticated"
          }
        )
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }
      let(:csrf_token) { fetch_csrf_token_for(user) }

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

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(User::Redemptions::ProcessJob).to have_received(:perform_in).with(
          2.seconds,
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
        redemption = user.redemptions.find_by(idempotency_key: key)
        expect(redemption).to be_present
        expect(redemption.status).to eq("processing")
      end

      it "returns bad_request when idempotency key header is missing" do
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "idempotency_key_required",
            "message" => "Idempotency-Key header is required"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      end

      it "returns bad_request when idempotency key format is invalid" do
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => "bad key with spaces", "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "invalid_idempotency_key",
            "message" => "Idempotency-Key must be 1-128 chars of letters, numbers, underscore, or dash"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      end

      it "returns existing status for duplicate idempotency key without enqueueing" do
        key = "406625f1-81c1-43e4-9e74-377e4c6ff31c"
        create(:user_redemption, user: user, reward: reward, idempotency_key: key, status: "completed")
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "data" => hash_including("request_id" => key, "status" => "completed")
        )
      end

      it "returns existing completed replay even if reward became unavailable" do
        key = "b4be53af-2867-4638-9aa6-4dbf3dd6482c"
        reward.update!(is_available: true)
        create(:user_redemption, user: user, reward: reward, idempotency_key: key, status: "completed")
        reward.update!(is_available: false)
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:ok)
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
        expect(JSON.parse(response.body)).to include(
          "data" => hash_including("request_id" => key, "status" => "completed")
        )
      end

      it "returns forbidden when reward is unavailable without creating processing row" do
        key = "a6c0950e-c554-4504-b4ae-ef90d8de6772"
        unavailable_reward = create(:reward, points_cost: 100, is_available: false)
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: unavailable_reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "forbidden",
            "message" => "Not authorized"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
        expect(user.redemptions.find_by(idempotency_key: key)).to be_nil
      end

      it "returns not_found when reward does not exist" do
        key = "3e32f8d6-cfbe-49e2-b030-1547559e3515"
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: 99_999_999 } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "not_found",
            "message" => "Resource not found"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      end

      it "returns bad_request when redemption param is missing" do
        key = "2f89f8cb-84d1-4d74-961a-fa4c2cccb5f9"
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: {},
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "parameter_missing",
            "message" => "param is missing or the value is empty or invalid: redemption"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      end

      it "returns unprocessable_entity when points_available is less than reward cost" do
        key = "f6b2a0f5-e8c1-40d7-a0d6-fd99dc19648e"
        expensive_reward = create(:reward, points_cost: 999, is_available: true)
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: expensive_reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "insufficient_balance",
            "message" => "Insufficient points balance"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
        expect(user.redemptions.find_by(idempotency_key: key)).to be_nil
      end

      it "checks affordability inside user lock and rejects when processing holds already consume balance" do
        key = "e95c8305-a768-47ab-9d8e-22de8ce8e5de"
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)
        create(
          :user_redemption,
          user: user,
          reward: reward,
          points_cost_snapshot: 250,
          status: "processing",
          idempotency_key: "inflight-1"
        )

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key, "X-CSRF-Token" => csrf_token }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "insufficient_balance",
            "message" => "Insufficient points balance"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
        expect(user.redemptions.find_by(idempotency_key: key)).to be_nil
      end

      it "returns forbidden when csrf token is missing" do
        key = "csfr-missing-14a3f0ff-62d9-4cc8-af5f-07d0ff67ad7b"
        allow(User::Redemptions::ProcessJob).to receive(:perform_in)

        post "/api/v1/user/redemptions",
             params: { redemption: { reward_id: reward.id } },
             headers: { "Idempotency-Key" => key }

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "invalid_csrf_token",
            "message" => "X-CSRF-Token is missing or invalid"
          }
        )
        expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
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
        processing = create(
          :user_redemption,
          user: user,
          reward: create(:reward),
          status: "processing",
          idempotency_key: "pending-123"
        )
        get "/api/v1/user/redemptions/pending-123"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "data" => {
            "request_id" => "pending-123",
            "id" => processing.id,
            "reward_id" => processing.reward_id,
            "points_cost_snapshot" => processing.points_cost_snapshot,
            "status" => "processing"
          }
        )
      end

      it "returns not_found when request id is unknown to cache and db" do
        get "/api/v1/user/redemptions/not-real-123"

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq(
          "error" => {
            "code" => "not_found",
            "message" => "No redemption found for request id"
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

      it "returns failed when redemption exists but is failed" do
        reward = create(:reward)
        create(
          :user_redemption,
          user: user,
          reward: reward,
          status: "failed",
          idempotency_key: "failed-123"
        )

        get "/api/v1/user/redemptions/failed-123"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to include(
          "data" => hash_including(
            "request_id" => "failed-123",
            "status" => "failed"
          )
        )
      end
    end
  end
end
