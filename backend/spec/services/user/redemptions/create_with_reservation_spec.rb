require "rails_helper"

RSpec.describe User::Redemptions::CreateWithReservation do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) { create(:reward, points_cost: 120) }
    let(:idempotency_key) { "ca022f41-0f0b-40df-8835-e0ca3c52f23d" }

    before do
      allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
      create(
        :user_point_transaction,
        user: user,
        amount: 500,
        running_balance: 500,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "29f622c5-eb39-4d68-9859-0e8092fbd007"
      )
      allow(User::Redemptions::AuditJob).to receive(:perform_async) do |payload|
        User::Redemptions::AuditJob.new.perform(payload.deep_stringify_keys)
      end
    end

    it "returns reservation_missing when processing redemption is not reserved first" do
      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "reservation_missing",
        message: "Redemption reservation was not found"
      )
      expect(user.redemptions.count).to eq(0)
      expect(user.point_transactions.count).to eq(1)
    end

    it "returns idempotent hit for duplicate key" do
      processing = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      first = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)
      second = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(first.success?).to be(true)
      expect(second.success?).to be(true)
      expect(second.redemption.id).to eq(processing.id)
      expect(user.redemptions.count).to eq(1)
    end

    it "returns reward_unavailable when reward cannot be redeemed" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      reward.update!(is_available: false)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "reward_unavailable")
    end

    it "returns insufficient_balance when points are not enough" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 900,
        status: "processing",
        idempotency_key: idempotency_key
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "insufficient_balance")
      expect(user.redemptions.count).to eq(1)
      expect(user.redemptions.find_by(idempotency_key: idempotency_key)&.status).to eq("processing")
    end

    it "rolls back points deduction when completion transition fails" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      allow_any_instance_of(User::Redemption).to receive(:complete!).and_raise(
        ActiveRecord::RecordInvalid.new(User::Redemption.new)
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "validation_error")
      expect(user.point_transactions.count).to eq(1)
      expect(user.point_transactions.order(:id).last.running_balance).to eq(500)
    end

    it "completes an existing processing redemption row" do
      processing = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(result.redemption.id).to eq(processing.id)
      expect(result.redemption.status).to eq("completed")
      debit = user.point_transactions.order(:id).last
      expect(debit.amount).to eq(-120)
      expect(debit.source).to eq(processing)
      expect(result.point_transaction.id).to eq(debit.id)
      update_audit = processing.audits.where(change_reason: "updated").order(:id).last
      expect(update_audit).to be_present
      expect(update_audit.snapshot).to include("status" => "completed")
      expect(update_audit.point_transaction_id).to eq(debit.id)
    end

    it "debits the reserved snapshot when reward points_cost changes after reservation" do
      processing = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 100,
        status: "processing",
        idempotency_key: idempotency_key
      )

      reward.update!(points_cost: 999)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(processing.reload.points_cost_snapshot).to eq(100)
      debit = user.point_transactions.order(:id).last
      expect(debit.amount).to eq(-100)
      expect(result.points_balance).to eq(400)
    end

    it "does not resurrect a failed redemption on replay with same idempotency key" do
      failed_redemption = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "failed",
        idempotency_key: idempotency_key
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "redemption_finalized",
        message: "Redemption already finalized"
      )
      expect(result.redemption).to be_nil
      expect(user.point_transactions.count).to eq(1)
      expect(failed_redemption.reload.status).to eq("failed")
    end

    it "does not resurrect a cancelled redemption on replay with same idempotency key" do
      cancelled_redemption = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "cancelled",
        idempotency_key: idempotency_key
      )

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "redemption_finalized",
        message: "Redemption already finalized"
      )
      expect(result.redemption).to be_nil
      expect(user.point_transactions.count).to eq(1)
      expect(cancelled_redemption.reload.status).to eq("cancelled")
    end

    it "re-raises unexpected exceptions so retries/error monitoring can capture them" do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      allow(User::PointTransactions::Create).to receive(:call).and_raise(NoMethodError, "boom")

      expect do
        described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)
      end.to raise_error(NoMethodError, "boom")
    end

    it "does not queue updated audit when state transition to completed fails" do
      processing = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      allow(User::Redemptions::AuditJob).to receive(:perform_async)
      allow_any_instance_of(User::Redemption).to receive(:complete!).and_return(false)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to include(code: "validation_error")
      expect(processing.reload.status).to eq("processing")
      expect(User::Redemptions::AuditJob).not_to have_received(:perform_async)
      expect(processing.audits).to be_empty
    end
  end
end
