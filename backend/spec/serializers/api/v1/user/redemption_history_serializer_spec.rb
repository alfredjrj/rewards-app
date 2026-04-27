require "rails_helper"

RSpec.describe Api::V1::User::RedemptionHistorySerializer do
  it "serializes redemption history row payload" do
    reward = create(:reward, title: "Coffee Voucher")
    created_at = Time.zone.parse("2026-04-27 09:15:00 UTC")
    redemption = create(
      :user_redemption,
      reward: reward,
      points_cost_snapshot: 100,
      status: "completed",
      created_at: created_at
    )

    payload = Api::V1::User::RedemptionHistorySerializer.call(redemption: redemption)

    expect(payload).to eq(
      data: {
        id: redemption.id,
        reward_id: reward.id,
        reward_title: "Coffee Voucher",
        points_cost_snapshot: 100,
        status: "completed",
        created_at: created_at
      }
    )
  end

  describe Api::V1::User::RedemptionHistorySerializer::Collection do
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

      payload = Api::V1::User::RedemptionHistorySerializer::Collection.call(redemptions: [ first, second ])

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
end
