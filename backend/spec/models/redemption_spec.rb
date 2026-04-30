require "rails_helper"

RSpec.describe User::Redemption, type: :model do
  before do
    allow(ActiveRecord).to receive(:after_all_transactions_commit).and_yield
    allow(User::Redemptions::AuditJob).to receive(:perform_async) do |payload|
      User::Redemptions::AuditJob.new.perform(payload.deep_stringify_keys)
    end
  end

  it "is valid with factory defaults" do
    expect(build(:user_redemption)).to be_valid
  end

  it "requires status to be supported" do
    redemption = build(:user_redemption, status: "pending")

    expect(redemption).not_to be_valid
    expect(redemption.errors[:status]).to include("is not included in the list")
  end

  it "requires non-negative points snapshot" do
    redemption = build(:user_redemption, points_cost_snapshot: -1)

    expect(redemption).not_to be_valid
    expect(redemption.errors[:points_cost_snapshot]).to include("must be greater than or equal to 0")
  end

  it "enforces idempotency_key uniqueness per user" do
    user = create(:user)
    key = "4db4d56a-8083-4f48-836c-2d63fc8e546e"
    create(:user_redemption, user: user, idempotency_key: key)
    duplicate = build(:user_redemption, user: user, idempotency_key: key)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:idempotency_key]).to include("has already been taken")
  end

  it "prevents destroy while an audit trail exists" do
    redemption = create(:user_redemption)
    User::Redemptions::Audit.record_async(
      redemption: redemption,
      change_reason: "created",
      change_source_origin: "system"
    )

    expect(redemption.destroy).to be(false)
    expect(redemption.errors[:base]).to include(
      "Cannot delete record because dependent audits exist"
    )
  end

  describe "audit snapshots" do
    it "does not auto-create audit rows from model callbacks" do
      redemption = create(:user_redemption, status: "processing")

      expect(redemption.audits).to be_empty
    end
  end

  describe "status transitions" do
    it "allows processing -> completed" do
      redemption = create(:user_redemption, status: "processing")

      expect { redemption.complete! }
        .to change { redemption.reload.status }
        .from("processing").to("completed")
    end

    it "rejects completed -> failed" do
      redemption = create(:user_redemption, status: "completed")

      expect(redemption.may_fail?).to be(false)
      expect(redemption.fail!).to be(false)
      expect(redemption.reload.status).to eq("completed")
    end

    it "exposes aasm guard helpers" do
      redemption = create(:user_redemption, status: "processing")

      expect(redemption.may_complete?).to be(true)
      expect(redemption.may_fail?).to be(true)
      expect(redemption.may_cancel?).to be(true)
    end
  end
end
