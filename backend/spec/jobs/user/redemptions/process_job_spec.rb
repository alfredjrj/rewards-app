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
end
