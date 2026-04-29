require "rails_helper"

RSpec.describe User::Redemption, type: :model do
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

  describe "audit snapshots" do
    it "creates a created audit row on insert" do
      redemption = create(:user_redemption, status: "processing")

      audit = redemption.audits.order(:id).last
      expect(audit).to be_present
      expect(audit.change_reason).to eq("created")
      expect(audit.snapshot).to include("status" => "processing")
      expect(audit.point_transaction_id).to be_nil
    end

    it "creates updated audit row and links related point transaction when present" do
      redemption = create(:user_redemption, status: "processing")
      points_tx = create(
        :user_point_transaction,
        user: redemption.user,
        amount: -redemption.points_cost_snapshot,
        running_balance: 0,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "status-change-tx-1",
        source: redemption
      )

      redemption.update!(status: "completed")

      audit = redemption.audits.where(change_reason: "updated").order(:id).last
      expect(audit).to be_present
      expect(audit.snapshot).to include("status" => "completed")
      expect(audit.point_transaction_id).to eq(points_tx.id)
    end
  end
end
