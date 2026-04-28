require "rails_helper"

RSpec.describe User::Redemptions::ProcessJob, type: :job do
  it "configures sidekiq retry and queue options" do
    expect(described_class.get_sidekiq_options).to include(
      "queue" => :default,
      "retry" => 5,
      "backtrace" => 5
    )
  end

  it "delegates perform to User::Redemptions::Process with job id" do
    allow(User::Redemptions::Process).to receive(:call)

    described_class.new.perform(1, 2, "req-id")

    expect(User::Redemptions::Process).to have_received(:call).with(
      hash_including(user_id: 1, reward_id: 2, request_id: "req-id")
    )
  end

  it "maps Process::TransientFailure to TransientRedemptionError for Sidekiq retries" do
    allow(User::Redemptions::Process).to receive(:call).and_raise(
      User::Redemptions::Process::TransientFailure,
      "Transient redemption processing failure"
    )

    expect do
      described_class.new.perform(9, 8, "key")
    end.to raise_error(User::Redemptions::ProcessJob::TransientRedemptionError)
  end

  describe ".handle_retries_exhausted" do
    it "delegates retries-exhausted finalization with parsed args" do
      allow(User::Redemptions::Process).to receive(:finalize_after_retries_exhausted)
      allow(Rails.logger).to receive(:error)

      described_class.handle_retries_exhausted(
        { "jid" => "jid-1", "args" => [ 1, 2, "req-1" ] },
        StandardError.new("boom")
      )

      expect(User::Redemptions::Process).to have_received(:finalize_after_retries_exhausted).with(
        user_id: 1,
        reward_id: 2,
        request_id: "req-1"
      )
      expect(Rails.logger).to have_received(:error).with(
        include("retries_exhausted jid=jid-1 user_id=1 reward_id=2 request_id=req-1 error=StandardError: boom")
      )
    end

    it "skips when required args are blank" do
      allow(User::Redemptions::Process).to receive(:finalize_after_retries_exhausted)

      described_class.handle_retries_exhausted({ "jid" => "jid-1", "args" => [ nil, 2, "req-1" ] }, StandardError.new("boom"))
      described_class.handle_retries_exhausted({ "jid" => "jid-1", "args" => [ 1, 2, "" ] }, StandardError.new("boom"))

      expect(User::Redemptions::Process).not_to have_received(:finalize_after_retries_exhausted)
    end
  end
end
