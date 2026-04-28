require "rails_helper"

RSpec.describe Api::V1::User::RedemptionSerializer do
  it "serializes redemption payload" do
    reward = create(:reward, title: "Coffee Voucher")
    created_at = Time.zone.parse("2026-04-27 09:15:00 UTC")
    redemption = create(
      :user_redemption,
      reward: reward,
      points_cost_snapshot: 120,
      status: "completed",
      created_at: created_at
    )

    payload = Api::V1::User::RedemptionSerializer.call(
      redemption: redemption
    )

    expect(payload).to eq(
      data: {
        id: redemption.id,
        reward_id: reward.id,
        reward_title: "Coffee Voucher",
        points_cost_snapshot: 120,
        status: "completed",
        created_at: created_at
      }
    )
  end

  describe Api::V1::User::RedemptionSerializer::Collection do
    it "serializes redemption history collection payload" do
      reward = create(:reward, title: "Coffee Voucher")
      first_created_at = Time.zone.parse("2026-04-27 09:15:00 UTC")
      second_created_at = Time.zone.parse("2026-04-27 09:16:00 UTC")
      first = create(
        :user_redemption,
        reward: reward,
        points_cost_snapshot: 100,
        status: "completed",
        created_at: first_created_at
      )
      second = create(
        :user_redemption,
        reward: reward,
        points_cost_snapshot: 200,
        status: "failed",
        created_at: second_created_at
      )

      payload = Api::V1::User::RedemptionSerializer::Collection.call(redemptions: [ first, second ])

      expect(payload).to eq(
        data: [
          {
            id: first.id,
            reward_id: reward.id,
            reward_title: "Coffee Voucher",
            points_cost_snapshot: 100,
            status: "completed",
            created_at: first_created_at
          },
          {
            id: second.id,
            reward_id: reward.id,
            reward_title: "Coffee Voucher",
            points_cost_snapshot: 200,
            status: "failed",
            created_at: second_created_at
          }
        ]
      )
    end
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
