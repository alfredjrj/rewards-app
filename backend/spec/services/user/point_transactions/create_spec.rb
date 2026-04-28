require "rails_helper"

RSpec.describe User::PointTransactions::Create do
  describe ".call" do
    let(:user) { create(:user) }

    it "creates a transaction with computed running balance" do
      result = described_class.call(
        user: user,
        amount: 300,
        kind: "earn",
        reason_code: "signup_bonus",
        idempotency_key: "8c2204ca-41e3-4ff5-aad0-7fca77b45361",
        reason: "Welcome reward"
      )

      expect(result.success?).to be(true)
      transaction = result.transaction
      expect(transaction).to be_persisted
      expect(transaction.running_balance).to eq(300)
      expect(transaction.amount).to eq(300)
    end

    it "returns the existing transaction for duplicate idempotency key" do
      key = "05972737-0af0-4f74-ae70-8f13d6f5181d"

      first_result = described_class.call(
        user: user,
        amount: 200,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: key
      )
      first = first_result.transaction

      second_result = described_class.call(
        user: user,
        amount: 999,
        kind: "adjustment",
        reason_code: "admin_correction",
        idempotency_key: key
      )
      second = second_result.transaction

      expect(first_result.success?).to be(true)
      expect(second_result.success?).to be(true)
      expect(second.id).to eq(first.id)
      expect(user.point_transactions.count).to eq(1)
      expect(second.amount).to eq(200)
    end

    it "increments from the latest running balance" do
      create(
        :user_point_transaction,
        user: user,
        amount: 500,
        running_balance: 500,
        kind: "earn",
        reason_code: "signup_bonus",
        idempotency_key: "f7cf2735-7e86-4fa0-a743-d059cd2b27bf"
      )

      result = described_class.call(
        user: user,
        amount: -120,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "394747ec-4524-4868-ae77-5ad5387db2f6"
      )

      expect(result.success?).to be(true)
      transaction = result.transaction
      expect(transaction.running_balance).to eq(380)
    end

    it "stores optional reason and polymorphic source" do
      reward = create(:reward)
      create(
        :user_point_transaction,
        user: user,
        amount: 300,
        running_balance: 300,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "4f5d7b74-0dfc-46cd-bf31-e0605bfd271d"
      )

      result = described_class.call(
        user: user,
        amount: -100,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "d4d7cf5b-7b1c-4f62-9fe7-f58bfd8f3210",
        reason: "Redeemed catalog reward",
        source: reward
      )

      expect(result.success?).to be(true)
      transaction = result.transaction
      expect(transaction.reason).to eq("Redeemed catalog reward")
      expect(transaction.source).to eq(reward)
    end

    it "uses user row locking during balance mutation" do
      expect(user).to receive(:with_lock).and_call_original

      result = described_class.call(
        user: user,
        amount: 50,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "737f4f2b-4cd2-4d0b-ad83-e7a381da4d16"
      )

      expect(result.success?).to be(true)
    end

    it "returns standardized insufficient balance error" do
      create(
        :user_point_transaction,
        user: user,
        amount: 100,
        running_balance: 100,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "6cf6d1ac-9fba-4287-a0c9-2c0322966c97"
      )

      result = described_class.call(
        user: user,
        amount: -150,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "8954d95f-c897-4640-8a4d-49f983ffdf94"
      )

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "insufficient_balance",
        message: "Insufficient points balance"
      )
    end

    it "returns standardized validation errors and does not create a transaction" do
      result = described_class.call(
        user: user,
        amount: 100,
        kind: "earn",
        reason_code: "invalid_reason_code",
        idempotency_key: "1918fed3-4183-4ec0-84bd-4e79fb61b17d"
      )

      expect(result.success?).to be(false)
      expect(result.error[:code]).to eq("validation_error")
      expect(result.error[:details]).to include(:reason_code)
      expect(user.point_transactions.count).to eq(0)
    end

    it "re-raises unexpected exceptions so retry/error monitoring can see them" do
      allow(user).to receive(:with_lock).and_raise(NoMethodError, "boom")

      expect do
        described_class.call(
          user: user,
          amount: 100,
          kind: "earn",
          reason_code: "purchase",
          idempotency_key: "45dbe3f4-4ab1-4f0d-a6cb-4ec2f6f2a244"
        )
      end.to raise_error(NoMethodError, "boom")
    end
  end
end
