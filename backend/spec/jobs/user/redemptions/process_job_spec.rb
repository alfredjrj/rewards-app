require "rails_helper"

RSpec.describe User::Redemptions::ProcessJob, type: :job do
  it "configures sidekiq retry and queue options" do
    expect(described_class.get_sidekiq_options).to include(
      "queue" => :default,
      "retry" => 5,
      "backtrace" => 5
    )
  end

  it "delegates perform to User::Redemptions::FinalizeProcessing with job id" do
    allow(User::Redemptions::FinalizeProcessing).to receive(:call)

    described_class.new.perform(1, 2, "req-id")

    expect(User::Redemptions::FinalizeProcessing).to have_received(:call).with(
      hash_including(user_id: 1, reward_id: 2, request_id: "req-id")
    )
  end

  it "maps FinalizeProcessing::TransientFailure to TransientRedemptionError for Sidekiq retries" do
    allow(User::Redemptions::FinalizeProcessing).to receive(:call).and_raise(
      User::Redemptions::FinalizeProcessing::TransientFailure,
      "Transient redemption processing failure"
    )

    expect do
      described_class.new.perform(9, 8, "key")
    end.to raise_error(User::Redemptions::ProcessJob::TransientRedemptionError)
  end
end
