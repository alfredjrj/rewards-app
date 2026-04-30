require "rails_helper"

RSpec.describe User::Redemptions::PlaceCreditHoldAndReserve do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) do
      create(
        :reward,
        points_cost: 100,
        is_available: true,
        reward_type: "vip_experience",
        fulfillment_provider: "ticketmaster"
      )
    end
    let(:idempotency_key) { "4feb0ed2-c6ca-466a-aea0-d3b9f8e54311" }

    before do
      allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
      create(
        :user_point_transaction,
        user: user,
        amount: 300,
        running_balance: 300,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "0482e2d5-a0f5-4f53-a8d0-2f97a6ff9a26"
      )
      allow(User::Redemptions::AuditJob).to receive(:perform_async) do |payload|
        User::Redemptions::AuditJob.new.perform(payload.deep_stringify_keys)
      end
    end

    it "creates a processing redemption and enqueues processing job" do
      allow(User::Redemptions::ProcessJob).to receive(:perform_in)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(User::Redemptions::ProcessJob).to have_received(:perform_in).with(2.seconds, user.id, reward.id, idempotency_key)
      redemption = user.redemptions.find_by(idempotency_key: idempotency_key)
      expect(redemption).to be_present
      expect(redemption.status).to eq("processing")
      audit = redemption.audits.order(:id).last
      expect(audit).to be_present
      expect(audit.change_reason).to eq("created")
      expect(audit.snapshot).to include("status" => "processing")
    end

    it "returns insufficient balance error when user cannot afford reward" do
      expensive_reward = create(:reward, points_cost: 999, is_available: true, fulfillment_provider: "ticketmaster")
      allow(User::Redemptions::ProcessJob).to receive(:perform_in)

      result = described_class.call(user: user, reward: expensive_reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "insufficient_balance",
        message: "Insufficient points balance"
      )
      expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      expect(user.redemptions.find_by(idempotency_key: idempotency_key)).to be_nil
    end

    it "short-circuits when redemption already exists for idempotency key" do
      existing = create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "processing",
        idempotency_key: idempotency_key
      )
      allow(User::Redemptions::ProcessJob).to receive(:perform_in)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(true)
      expect(result[:redemption]).to eq(existing)
      expect(User::Redemptions::ProcessJob).not_to have_received(:perform_in)
      expect(user.redemptions.where(idempotency_key: idempotency_key).count).to eq(1)
    end

    it "returns enqueue_unavailable and marks row failed when enqueue fails" do
      allow(User::Redemptions::ProcessJob).to receive(:perform_in).and_raise(StandardError, "redis down")

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      expect(result.error).to eq(
        code: "enqueue_unavailable",
        message: "Redemption queue is temporarily unavailable. Please try again."
      )
      redemption = user.redemptions.find_by(idempotency_key: idempotency_key)
      expect(redemption).to be_present
      expect(redemption.status).to eq("failed")
      update_audit = redemption.audits.where(change_reason: "updated").order(:id).last
      expect(update_audit).to be_present
      expect(update_audit.snapshot).to include("status" => "failed")
    end

    it "does not queue updated audit when transition to failed is rejected" do
      allow(User::Redemptions::ProcessJob).to receive(:perform_in).and_raise(StandardError, "redis down")
      allow(Rails.logger).to receive(:error)
      allow_any_instance_of(User::Redemption).to receive(:fail!).and_return(false)

      result = described_class.call(user: user, reward: reward, idempotency_key: idempotency_key)

      expect(result.success?).to be(false)
      redemption = user.redemptions.find_by(idempotency_key: idempotency_key)
      expect(redemption).to be_present
      expect(redemption.status).to eq("processing")
      expect(redemption.audits.pluck(:change_reason)).to eq([ "created" ])
      expect(Rails.logger).to have_received(:error).with(include("[redemption.place_credit_hold_and_reserve] transition_failed"))
    end

    it "creates exactly one processing redemption under concurrent calls with same idempotency key", :concurrency do
      allow(User::Redemptions::ProcessJob).to receive(:perform_in)
      key = SecureRandom.uuid
      results = Queue.new
      thread_count = 5
      start_gate = Queue.new

      threads = thread_count.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            start_gate.pop
            thread_user = User.find(user.id)
            thread_reward = Reward.find(reward.id)
            results << described_class.call(user: thread_user, reward: thread_reward, idempotency_key: key)
          end
        end
      end

      thread_count.times { start_gate << true }
      threads.each(&:join)

      all_results = []
      all_results << results.pop until results.empty?

      expect(all_results).to all(satisfy(&:success?))
      expect(user.redemptions.where(idempotency_key: key).count).to eq(1)
      expect(User::Redemptions::ProcessJob).to have_received(:perform_in).once
    end
  end
end
