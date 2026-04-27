require "rails_helper"

RSpec.describe Api::V1::User::RedemptionSerializer do
  it "serializes redemption payload" do
    redemption = create(:user_redemption, points_cost_snapshot: 120, status: "completed")

    payload = Api::V1::User::RedemptionSerializer.call(
      redemption: redemption
    )

    expect(payload).to eq(
      data: {
        id: redemption.id,
        reward_id: redemption.reward_id,
        points_cost_snapshot: 120,
        status: "completed"
      }
    )
  end

  describe Api::V1::User::RedemptionSerializer::Status do
    it "serializes processing status payload" do
      payload = Api::V1::User::RedemptionSerializer::Status.call(
        request_id: "req-123",
        reward_id: 12,
        status: "processing"
      )

      expect(payload).to eq(
        data: {
          request_id: "req-123",
          reward_id: 12,
          status: "processing"
        }
      )
    end

    it "serializes completed status payload" do
      redemption = create(:user_redemption, points_cost_snapshot: 120, status: "completed")

      payload = Api::V1::User::RedemptionSerializer::Status.call(
        request_id: "req-123",
        status: "completed",
        redemption: redemption
      )

      expect(payload).to eq(
        data: {
          request_id: "req-123",
          id: redemption.id,
          reward_id: redemption.reward_id,
          points_cost_snapshot: 120,
          status: "completed"
        }
      )
    end

    it "serializes failed status payload" do
      payload = Api::V1::User::RedemptionSerializer::Status.call(
        request_id: "req-123",
        reward_id: 99,
        status: "failed",
        error: { code: "insufficient_balance", message: "Insufficient points balance" }
      )

      expect(payload).to eq(
        data: {
          request_id: "req-123",
          reward_id: 99,
          status: "failed",
          error: {
            code: "insufficient_balance",
            message: "Insufficient points balance"
          }
        }
      )
    end
  end
end
