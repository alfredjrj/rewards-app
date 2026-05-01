require "rails_helper"

RSpec.describe User::Redemptions::Create, "with reservation_mode: :none" do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) { create(:reward, points_cost: 120, fulfillment_provider: "internal") }
    let(:idempotency_key) { "f012be42-1f38-4ee9-b337-1749f7ebc3ce" }

    before do
      allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
      create(
        :user_point_transaction,
        user: user,
        amount: 500,
        running_balance: 500,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "seed-sync-balance-2"
      )
      allow(User::Redemptions::AuditJob).to receive(:perform_async) do |payload|
        User::Redemptions::AuditJob.new.perform(payload.deep_stringify_keys)
      end
    end

    it "completes redemption inline without creating processing hold" do
      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(result.redemption.status).to eq("completed")
      debit = user.point_transactions.order(:id).last
      expect(debit.amount).to eq(-120)
      expect(debit.source).to be_nil
    end

    it "returns idempotent completed replay for duplicate key" do
      first = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)
      second = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(first.success?).to be(true)
      expect(second.success?).to be(true)
      expect(second.redemption.id).to eq(first.redemption.id)
      expect(user.redemptions.where(idempotency_key: idempotency_key).count).to eq(1)
    end

    it "returns insufficient_balance when user cannot afford reward" do
      expensive_reward = create(:reward, points_cost: 999, is_available: true, fulfillment_provider: "internal")

      result = described_class.call(user: user, reward: expensive_reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(
        code: "insufficient_balance",
        message: "Insufficient points balance"
      )
      expect(user.redemptions.where(idempotency_key: idempotency_key)).to be_empty
    end
  end
end
