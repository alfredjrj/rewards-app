require "rails_helper"

RSpec.describe User::Redemptions::Create do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) { create(:reward, points_cost: 120) }
    let(:idempotency_key) { "ca022f41-0f0b-40df-8835-e0ca3c52f23d" }

    before do
      create(
        :user_point_transaction,
        user: user,
        amount: 500,
        running_balance: 500,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "29f622c5-eb39-4d68-9859-0e8092fbd007"
      )
    end

    it "creates redemption and deducts user points" do
      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(result.redemption).to be_persisted
      expect(result.redemption.reward).to eq(reward)
      expect(result.points_balance).to eq(380)
      expect(user.point_transactions.order(:id).last.amount).to eq(-120)
    end

    it "returns idempotent hit for duplicate key" do
      first = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)
      second = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(first.success?).to be(true)
      expect(second.success?).to be(true)
      expect(second.redemption.id).to eq(first.redemption.id)
      expect(user.redemptions.count).to eq(1)
    end

    it "returns reward_unavailable when reward cannot be redeemed" do
      reward.update!(is_available: false)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "reward_unavailable")
    end

    it "returns insufficient_balance when points are not enough" do
      reward.update!(points_cost: 900)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "insufficient_balance")
      expect(user.redemptions.count).to eq(0)
    end

    it "rolls back points deduction when redemption creation fails" do
      allow(User::Redemption).to receive(:create!).and_raise(
        ActiveRecord::RecordInvalid.new(User::Redemption.new)
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "validation_error")
      expect(user.redemptions.count).to eq(0)
      expect(user.point_transactions.count).to eq(1)
      expect(user.point_transactions.order(:id).last.running_balance).to eq(500)
    end

    it "re-raises unexpected exceptions so retries/error monitoring can capture them" do
      allow(User::PointTransactions::Create).to receive(:call).and_raise(NoMethodError, "boom")

      expect do
        described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)
      end.to raise_error(NoMethodError, "boom")
    end
  end
end
