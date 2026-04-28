require "rails_helper"

RSpec.describe User::PointTransaction, type: :model do
  describe "associations" do
    it "belongs to a user" do
      transaction = build(:user_point_transaction, user: nil)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:user]).to include("must exist")
    end
  end

  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:user_point_transaction)).to be_valid
    end

    it "requires amount to be non-zero" do
      transaction = build(:user_point_transaction, amount: 0)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:amount]).to include("must be other than 0")
    end

    it "requires running_balance to be non-negative" do
      transaction = build(:user_point_transaction, running_balance: -1)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:running_balance]).to include("must be greater than or equal to 0")
    end

    it "requires kind to be in the supported list" do
      transaction = build(:user_point_transaction, kind: "bonus")

      expect(transaction).not_to be_valid
      expect(transaction.errors[:kind]).to include("is not included in the list")
    end

    it "requires reason_code to be in the supported list" do
      transaction = build(:user_point_transaction, reason_code: "valid_transaction")

      expect(transaction).not_to be_valid
      expect(transaction.errors[:reason_code]).to include("is not included in the list")
    end

    it "enforces idempotency_key uniqueness per user" do
      user = create(:user)
      key = "22f064cc-62ca-4ca2-9446-fca04ff26f89"
      create(:user_point_transaction, user: user, idempotency_key: key)
      duplicate = build(:user_point_transaction, user: user, idempotency_key: key)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:idempotency_key]).to include("has already been taken")
    end

    it "allows Reward as a source type" do
      reward = create(:reward)
      transaction = build(:user_point_transaction, source: reward)

      expect(transaction).to be_valid
    end

    it "allows User::Redemption as a source type" do
      redemption = create(:user_redemption)
      transaction = build(:user_point_transaction, source: redemption)

      expect(transaction).to be_valid
    end

    it "rejects unsupported source types" do
      transaction = build(:user_point_transaction)
      transaction.source_type = "User"
      transaction.source_id = 1

      expect(transaction).not_to be_valid
      expect(transaction.errors[:source_type]).to include("is not included in the list")
    end
  end
end
