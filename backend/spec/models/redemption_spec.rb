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
end
