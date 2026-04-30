require "rails_helper"

RSpec.describe User::Redemptions::AuditJob, type: :job do
  describe "#perform" do
    it "creates a redemption audit from payload" do
      redemption = create(:user_redemption, status: "processing")
      payload = {
        "user_redemption_id" => redemption.id,
        "user_id" => redemption.user_id,
        "reward_id" => redemption.reward_id,
        "point_transaction_id" => nil,
        "request_id" => redemption.idempotency_key,
        "event_at" => Time.current.iso8601(6),
        "change_source_origin" => "background_job",
        "change_reason" => "updated",
        "snapshot" => User::Redemptions::Audit.snapshot_for(redemption),
        "metadata" => { "phase" => "job" }
      }

      expect { described_class.new.perform(payload) }.to change(User::RedemptionAudit, :count).by(1)
      created = User::RedemptionAudit.order(:id).last
      expect(created.change_source_origin).to eq("background_job")
      expect(created.event_at.iso8601(6)).to eq(payload.fetch("event_at"))
      expect(created.metadata).to include("phase" => "job")
    end
  end

  describe "sidekiq retries exhausted" do
    it "logs payload details for reconciliation" do
      allow(Rails.logger).to receive(:error)
      sidekiq_msg = {
        "jid" => "audit-jid-1",
        "retry_count" => 10,
        "args" => [
          {
            "user_redemption_id" => 123,
            "request_id" => "req-123",
            "change_reason" => "updated"
          }
        ]
      }

      described_class.sidekiq_retries_exhausted_block.call(sidekiq_msg, StandardError.new("redis timeout"))
      expect(Rails.logger).to have_received(:error).with(include("[redemption.audit_job] retries_exhausted"))
    end
  end
end
