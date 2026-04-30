require "rails_helper"

RSpec.describe User::Redemptions::Validate do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) { create(:reward, points_cost: 120) }
    let(:idempotency_key) { SecureRandom.uuid }

    it "returns replay success for an existing completed redemption" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "completed",
        idempotency_key: idempotency_key
      )

      result = described_class.call(
        user: user,
        reward: reward,
        idempotency_key: idempotency_key,
        flow: :sync
      )

      expect(result.halt?).to be(true)
      expect(result.success?).to be(true)
      expect(result.existing_redemption.status).to eq("completed")
    end

    it "returns reward_unavailable before flow-specific checks" do
      reward.update!(is_available: false)

      result = described_class.call(
        user: user,
        reward: reward,
        idempotency_key: idempotency_key,
        flow: :with_reservation
      )

      expect(result.halt?).to be(true)
      expect(result.success?).to be(false)
      expect(result.error_code).to eq("reward_unavailable")
    end

    it "returns redemption_in_progress for sync flow with existing processing redemption" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "processing",
        idempotency_key: idempotency_key
      )

      result = described_class.call(
        user: user,
        reward: reward,
        idempotency_key: idempotency_key,
        flow: :sync
      )

      expect(result.halt?).to be(true)
      expect(result.success?).to be(false)
      expect(result.error_code).to eq("redemption_in_progress")
    end

    it "returns reservation_missing for with_reservation flow when no redemption exists" do
      result = described_class.call(
        user: user,
        reward: reward,
        idempotency_key: idempotency_key,
        flow: :with_reservation
      )

      expect(result.halt?).to be(true)
      expect(result.success?).to be(false)
      expect(result.error_code).to eq("reservation_missing")
    end
  end
end
