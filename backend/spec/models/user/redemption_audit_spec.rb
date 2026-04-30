require "rails_helper"

RSpec.describe User::RedemptionAudit, type: :model do
  let(:user) { create(:user) }
  let(:reward) { create(:reward) }
  let(:redemption) do
    create(
      :user_redemption,
      user: user,
      reward: reward,
      status: "processing",
      idempotency_key: "audit-spec-key-1"
    )
  end

  it "accepts supported change reasons" do
    described_class::CHANGE_REASONS.each do |change_reason|
      audit = described_class.new(
        redemption: redemption,
        user: user,
        reward: reward,
        request_id: redemption.idempotency_key,
        change_source_origin: "api_request",
        change_reason: change_reason,
        snapshot: { status: redemption.status }
      )

      expect(audit).to be_valid
    end
  end

  it "rejects change_reason values outside CHANGE_REASONS" do
    audit = described_class.new(
      redemption: redemption,
      user: user,
      reward: reward,
      request_id: redemption.idempotency_key,
      change_source_origin: "api_request",
      change_reason: "deleted",
      snapshot: { status: redemption.status }
    )

    expect(audit).not_to be_valid
    expect(audit.errors[:change_reason]).to include("is not included in the list")
  end

  it "rejects change_source_origin values outside CHANGE_SOURCES" do
    audit = described_class.new(
      redemption: redemption,
      user: user,
      reward: reward,
      request_id: redemption.idempotency_key,
      change_source_origin: "admin_console",
      change_reason: "updated",
      snapshot: { status: redemption.status }
    )

    expect(audit).not_to be_valid
    expect(audit.errors[:change_source_origin]).to include("is not included in the list")
  end

  it "requires snapshot payload" do
    audit = described_class.new(
      redemption: redemption,
      user: user,
      reward: reward,
      request_id: redemption.idempotency_key,
      change_source_origin: "api_request",
      change_reason: "updated",
      snapshot: nil
    )

    expect(audit).not_to be_valid
    expect(audit.errors[:snapshot]).to include("can't be blank")
  end

  it "allows audits without a linked point transaction" do
    audit = described_class.new(
      redemption: redemption,
      user: user,
      reward: reward,
      request_id: redemption.idempotency_key,
      change_source_origin: "background_job",
      change_reason: "updated",
      snapshot: { status: redemption.status },
      point_transaction: nil
    )

    expect(audit).to be_valid
  end

  it "requires change_source_origin and request_id" do
    audit = described_class.new(
      redemption: redemption,
      user: user,
      reward: reward,
      request_id: nil,
      change_source_origin: nil,
      change_reason: "updated",
      snapshot: { status: redemption.status }
    )

    expect(audit).not_to be_valid
    expect(audit.errors[:request_id]).to include("can't be blank")
    expect(audit.errors[:change_source_origin]).to include("can't be blank")
  end
end
