require "rails_helper"

RSpec.describe User::Points::AvailableBalance do
  describe ".call" do
    let(:user) { create(:user) }

    it "returns zeroes when user has no transactions" do
      expect(described_class.call(user: user)).to eq(
        points_balance: 0,
        points_pending_redemption: 0,
        points_available: 0
      )
    end

    it "returns ledger balance, pending processing points, and available points" do
      create(
        :user_point_transaction,
        user: user,
        amount: 500,
        running_balance: 500,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "eb4222e2-fa2b-4483-a2a3-24f8eb8f1065"
      )
      create(
        :user_point_transaction,
        user: user,
        amount: -100,
        running_balance: 400,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "f9fb0f2e-8517-4069-b08c-3ff9d645ad2c"
      )

      reward = create(:reward, points_cost: 75)
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 75,
        status: "processing",
        idempotency_key: "processing-1"
      )
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 75,
        status: "completed",
        idempotency_key: "completed-1"
      )

      expect(described_class.call(user: user)).to eq(
        points_balance: 400,
        points_pending_redemption: 75,
        points_available: 325
      )
    end

    it "clamps available points to zero" do
      create(
        :user_point_transaction,
        user: user,
        amount: 50,
        running_balance: 50,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "84af2587-72e8-4aa4-86fc-cab58a8fd3f2"
      )
      reward = create(:reward, points_cost: 80)
      create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 80,
        status: "processing",
        idempotency_key: "processing-2"
      )

      expect(described_class.call(user: user)).to eq(
        points_balance: 50,
        points_pending_redemption: 80,
        points_available: 0
      )
    end

    it "keeps available points consistent while redemption transitions from processing to completed", :concurrency do
      reward = create(:reward, points_cost: 100)
      create(
        :user_point_transaction,
        user: user,
        amount: 100,
        running_balance: 100,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: SecureRandom.uuid
      )
      redemption = create(
        :user_redemption,
        user: user,
        reward: reward,
        points_cost_snapshot: 100,
        status: "processing",
        idempotency_key: SecureRandom.uuid
      )

      writer_started = Queue.new
      writer_done = Queue.new

      writer = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          writer_started << true
          ActiveRecord::Base.transaction do
            redemption.reload.update!(status: "completed")
            User::PointTransaction.create!(
              user: user,
              amount: -100,
              running_balance: 0,
              kind: "redeem",
              reason_code: "reward_redemption",
              idempotency_key: SecureRandom.uuid
            )
            sleep 0.05
          end
          writer_done << true
        end
      end

      writer_started.pop
      snapshots = []
      250.times do
        snapshots << described_class.call(user: user)[:points_available]
        break unless writer_done.empty?
      end
      writer.join
      50.times { snapshots << described_class.call(user: user)[:points_available] }

      expect(snapshots).to all(eq(0))
    end
  end
end
