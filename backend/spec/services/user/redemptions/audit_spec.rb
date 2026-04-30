require "rails_helper"

RSpec.describe User::Redemptions::Audit do
  describe ".record" do
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

    it "uses explicit change_source_origin and merges metadata with precedence to method args" do
      redemption.assign_change_source_origin(
        change_source_origin: "api_request",
        change_source_metadata: { "base" => "from_redemption", "shared" => "redemption" }
      )

      audit = described_class.record(
        redemption: redemption,
        change_reason: "updated",
        change_source_origin: "background_job",
        change_source_metadata: { "shared" => "call", "extra" => "value" }
      )

      expect(audit).to be_persisted
      expect(audit.change_source_origin).to eq("background_job")
      expect(audit.metadata).to eq(
        "base" => "from_redemption",
        "shared" => "call",
        "extra" => "value"
      )
    end

    it "falls back to redemption.change_source_origin when explicit origin is missing" do
      redemption.assign_change_source_origin(change_source_origin: "api_request", change_source_metadata: {})

      audit = described_class.record(
        redemption: redemption,
        change_reason: "updated"
      )

      expect(audit).to be_persisted
      expect(audit.change_source_origin).to eq("api_request")
    end

    it "falls back to system when neither explicit nor redemption origin exists" do
      redemption.change_source_origin = nil
      redemption.change_source_metadata = nil

      audit = described_class.record(
        redemption: redemption,
        change_reason: "updated"
      )

      expect(audit).to be_persisted
      expect(audit.change_source_origin).to eq("system")
      expect(audit.metadata).to eq({})
    end

    it "logs and returns an unsaved audit when validations fail" do
      allow(Rails.logger).to receive(:error)

      audit = described_class.record(
        redemption: redemption,
        change_reason: "invalid_reason",
        change_source_origin: "api_request"
      )

      expect(audit).not_to be_persisted
      expect(audit.errors[:change_reason]).to include("is not included in the list")
      expect(Rails.logger).to have_received(:error).with(include("[redemption.audit] persist_failed"))
    end
  end

  describe ".snapshot_for" do
    let(:redemption) { create(:user_redemption, status: "processing", idempotency_key: "audit-payload-key-1") }

    it "returns a compact snapshot payload from the redemption" do
      snapshot = described_class.snapshot_for(redemption)

      expect(snapshot).to eq(
        id: redemption.id,
        user_id: redemption.user_id,
        reward_id: redemption.reward_id,
        status: redemption.status,
        points_cost_snapshot: redemption.points_cost_snapshot,
        idempotency_key: redemption.idempotency_key
      )
    end
  end
end
