require "rails_helper"

RSpec.describe User::Redemptions::Process do
  describe ".call" do
    it "runs Create and broadcasts completed status" do
      user = create(:user)
      reward = create(:reward)
      key = "b87d35ad-bc4f-42bc-b94c-ed00356e7238"
      result = instance_double(
        "ServiceResponse",
        success?: true,
        redemption: instance_double(User::Redemption, reward_id: reward.id)
      )
      allow(User::Redemptions::Create).to receive(:call).and_return(result)
      allow(ActionCable.server).to receive(:broadcast)

      described_class.call(user_id: user.id, reward_id: reward.id, request_id: key)

      expect(User::Redemptions::Create).to have_received(:call).with(
        user: user,
        reward: reward,
        idempotency_key: key
      )
      expect(ActionCable.server).to have_received(:broadcast).with(
        "user_redemptions:#{user.id}",
        hash_including(
          request_id: key,
          reward_id: reward.id,
          status: "completed"
        )
      )
    end

    it "raises TransientFailure for infrastructure errors" do
      user = create(:user)
      reward = create(:reward)
      key = "deadbeef-dead-beef-dead-beefdeadbeef"
      allow(User).to receive(:find).with(user.id).and_raise(ActiveRecord::Deadlocked.new("deadlock"))
      expect(User::Redemptions::Create).not_to receive(:call)

      expect do
        described_class.call(user_id: user.id, reward_id: reward.id, request_id: key)
      end.to raise_error(described_class::TransientFailure)
    end

    it "publishes not_found without raising when record is missing" do
      user = create(:user)
      reward = create(:reward)
      key = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
      allow(User).to receive(:find).with(user.id).and_raise(
        ActiveRecord::RecordNotFound.new("Couldn't find User")
      )
      allow(ActionCable.server).to receive(:broadcast)
      expect(User::Redemptions::Create).not_to receive(:call)

      expect do
        described_class.call(user_id: user.id, reward_id: reward.id, request_id: key)
      end.not_to raise_error

      expect(ActionCable.server).to have_received(:broadcast).with(
        "user_redemptions:#{user.id}",
        hash_including(
          request_id: key,
          status: "failed",
          error: hash_including(code: "not_found")
        )
      )
    end

    it "raises TransientFailure when Create returns internal_error" do
      user = create(:user)
      reward = create(:reward)
      key = "3f359ceb-57d3-4200-aad6-c4ca0bb5e839"
      result = instance_double(
        "ServiceResponse",
        success?: false,
        error: { code: "internal_error", message: "Unable to redeem reward" }
      )
      allow(User::Redemptions::Create).to receive(:call).and_return(result)
      allow(ActionCable.server).to receive(:broadcast)

      expect do
        described_class.call(user_id: user.id, reward_id: reward.id, request_id: key)
      end.to raise_error(described_class::TransientFailure, "Transient redemption processing failure")

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it "publishes domain failure without retry for non-internal_error codes" do
      user = create(:user)
      reward = create(:reward)
      key = "11111111-2222-3333-4444-555555555555"
      error = { code: "insufficient_balance", message: "Not enough points" }
      result = instance_double("ServiceResponse", success?: false, error: error)
      allow(User::Redemptions::Create).to receive(:call).and_return(result)
      allow(ActionCable.server).to receive(:broadcast)

      described_class.call(user_id: user.id, reward_id: reward.id, request_id: key)

      expect(ActionCable.server).to have_received(:broadcast).with(
        "user_redemptions:#{user.id}",
        hash_including(request_id: key, status: "failed", error: error)
      )
    end
  end

  describe ".finalize_after_retries_exhausted" do
    it "broadcasts terminal internal_error payload" do
      user = create(:user)
      reward = create(:reward)
      create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "processing",
        idempotency_key: "req-123"
      )
      allow(ActionCable.server).to receive(:broadcast)

      described_class.finalize_after_retries_exhausted(
        user_id: user.id,
        reward_id: reward.id,
        request_id: "req-123"
      )

      expect(ActionCable.server).to have_received(:broadcast).with(
        "user_redemptions:#{user.id}",
        hash_including(
          request_id: "req-123",
          reward_id: reward.id,
          status: "failed",
          error: hash_including(code: "internal_error")
        )
      )
    end

    it "does nothing when user_id or request_id is blank" do
      allow(ActionCable.server).to receive(:broadcast)

      described_class.finalize_after_retries_exhausted(user_id: nil, reward_id: 1, request_id: "r")
      described_class.finalize_after_retries_exhausted(user_id: 1, reward_id: 1, request_id: "")

      expect(ActionCable.server).not_to have_received(:broadcast)
    end

    it "does not broadcast failed when redemption is already completed" do
      user = create(:user)
      reward = create(:reward)
      create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "completed",
        idempotency_key: "req-123"
      )
      allow(ActionCable.server).to receive(:broadcast)

      described_class.finalize_after_retries_exhausted(
        user_id: user.id,
        reward_id: reward.id,
        request_id: "req-123"
      )

      expect(ActionCable.server).not_to have_received(:broadcast)
    end
  end

  describe User::Redemptions::StatusTransition do
    describe ".mark" do
    it "does not demote completed to failed" do
      user = create(:user)
      reward = create(:reward)
      redemption = create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "completed",
        idempotency_key: "req-123"
      )

      updated = described_class.mark(
        user_id: user.id,
        request_id: "req-123",
        status: "failed"
      )

      expect(updated).to be(false)
      expect(redemption.reload.status).to eq("completed")
    end
    end
  end
end
