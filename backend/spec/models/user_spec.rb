require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it "has many point transactions" do
      user = create(:user)
      create(:user_point_transaction, user: user)

      expect(user.point_transactions.count).to eq(1)
      expect(user.point_transactions.first).to be_a(User::PointTransaction)
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
