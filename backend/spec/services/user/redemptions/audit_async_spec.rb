require "rails_helper"

RSpec.describe User::Redemptions::AuditAsync do
  describe ".call" do
    let(:user) { create(:user) }
    let(:reward) { create(:reward) }
    let(:redemption) do
      create(
        :user_redemption,
        user: user,
        reward: reward,
        status: "processing",
        idempotency_key: "audit-service-key-1"
      )
    end

    before do
      allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
      allow(User::Redemptions::AuditJob).to receive(:perform_async) do |payload|
        User::Redemptions::AuditJob.new.perform(payload.deep_stringify_keys)
      end
    end

    it "uses explicit change_source_origin and persists provided metadata" do
      payload = described_class.call(
        redemption: redemption,
        change_reason: "updated",
        change_source_origin: "background_job",
        change_source_metadata: { "shared" => "call", "extra" => "value" }
      )

      expect(payload).to include(change_source_origin: "background_job")
      expect(payload[:event_at]).to be_present
      audit = redemption.audits.order(:id).last
      expect(audit).to be_present
      expect(audit.change_source_origin).to eq("background_job")
      expect(audit.event_at.iso8601(6)).to eq(payload.fetch(:event_at))
      expect(audit.metadata).to eq(
        "shared" => "call",
        "extra" => "value"
      )
    end

    it "falls back to system when origin is omitted" do
      payload = described_class.call(
        redemption: redemption,
        change_reason: "updated"
      )

      expect(payload).to include(change_source_origin: "system")
      audit = redemption.audits.order(:id).last
      expect(audit).to be_present
      expect(audit.change_source_origin).to eq("system")
      expect(audit.metadata).to eq({})
    end

    it "logs and skips persistence when job enqueue fails" do
      allow(Rails.logger).to receive(:error)
      allow(User::Redemptions::AuditJob).to receive(:perform_async).and_raise(StandardError, "redis down")

      payload = described_class.call(
        redemption: redemption,
        change_reason: "invalid_reason",
        change_source_origin: "api_request"
      )

      expect(payload).to include(change_reason: "invalid_reason")
      expect(redemption.audits).to be_empty
      expect(Rails.logger).to have_received(:error).with(include("[redemption.audit] enqueue_failed"))
    end
  end

  describe ".snapshot_for" do
    let(:redemption) { create(:user_redemption, status: "processing", idempotency_key: "audit-payload-key-1") }

    it "returns a compact snapshot payload from the redemption" do
      snapshot = described_class.snapshot_for(redemption)

      expect(snapshot).to eq(
        "id" => redemption.id,
        "user_id" => redemption.user_id,
        "reward_id" => redemption.reward_id,
        "status" => redemption.status,
        "points_cost_snapshot" => redemption.points_cost_snapshot,
        "idempotency_key" => redemption.idempotency_key
      )
    end
  end
end
