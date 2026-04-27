require "rails_helper"

RSpec.describe "Redemption serializers" do
  describe Api::V1::User::RedemptionSerializer do
    it "serializes create response payload" do
      redemption = create(:user_redemption, points_cost_snapshot: 120, status: "completed")

      payload = Api::V1::User::RedemptionSerializer.call(
        redemption: redemption,
        points_balance: 380
      )

      expect(payload).to eq(
        id: redemption.id,
        reward_id: redemption.reward_id,
        points_cost_snapshot: 120,
        status: "completed",
        points_balance: 380
      )
    end
  end

  describe Api::V1::User::RedemptionHistorySerializer do
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
        id: redemption.id,
        reward_id: reward.id,
        reward_title: "Coffee Voucher",
        points_cost_snapshot: 100,
        status: "completed",
        created_at: created_at
      )
    end
  end

  describe Api::V1::User::RedemptionHistoryCollectionSerializer do
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

      payload = Api::V1::User::RedemptionHistoryCollectionSerializer.call(redemptions: [ first, second ])

      expect(payload).to eq([
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
      ])
    end
  end

  describe Api::V1::PaginationMetaSerializer do
    it "serializes pagy metadata payload" do
      pagy = double("pagy", page: 2, limit: 10, count: 35, pages: 4)

      payload = Api::V1::PaginationMetaSerializer.call(pagy: pagy)

      expect(payload).to eq(
        page: 2,
        per_page: 10,
        total_count: 35,
        total_pages: 4
      )
    end
  end
end
