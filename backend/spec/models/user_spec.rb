require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it "has many point transactions" do
      user = create(:user)
      create(:user_point_transaction, user: user)

      expect(user.point_transactions.count).to eq(1)
      expect(user.point_transactions.first).to be_a(User::PointTransaction)
    end

    it "prevents destroying users with point transactions to preserve ledger history" do
      user = create(:user)
      create(:user_point_transaction, user: user)

      expect(user.destroy).to be(false)
      expect(user.errors[:base]).to include("Cannot delete record because dependent point transactions exist")
    end

    it "prevents destroying users with redemptions to preserve redemption audit history" do
      user = create(:user)
      create(:user_redemption, user: user)

      expect(user.destroy).to be(false)
      expect(user.errors[:base]).to include("Cannot delete record because dependent redemptions exist")
    end
  end

  describe "#current_points_balance" do
    it "returns zero when the user has no point transactions" do
      user = create(:user)

      expect(user.current_points_balance).to eq(0)
    end

    it "returns latest running balance by id" do
      user = create(:user)
      create(
        :user_point_transaction,
        user: user,
        amount: 100,
        running_balance: 100,
        kind: "earn",
        reason_code: "purchase",
        idempotency_key: "tx-1"
      )
      create(
        :user_point_transaction,
        user: user,
        amount: -20,
        running_balance: 80,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: "tx-2"
      )

      expect(user.current_points_balance).to eq(80)
    end
  end

  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:user)).to be_valid
    end

    it "requires an email" do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("can't be blank")
    end

    it "requires a properly formatted email" do
      user = build(:user, email: "invalid-email")

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("is invalid")
    end

    it "requires email to be unique" do
      create(:user, email: "taken@example.com")
      user = build(:user, email: "taken@example.com")

      expect(user).not_to be_valid
      expect(user.errors[:email]).to include("has already been taken")
    end

    it "requires password to be at least 8 characters" do
      user = build(:user, password: "1234567", password_confirmation: "1234567")

      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 8 characters)")
    end
  end
end
