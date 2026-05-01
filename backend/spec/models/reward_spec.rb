require "rails_helper"

RSpec.describe Reward, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:reward)).to be_valid
    end

    it "requires a title" do
      reward = build(:reward, title: nil)

      expect(reward).not_to be_valid
      expect(reward.errors[:title]).to include("can't be blank")
    end

    it "requires a description" do
      reward = build(:reward, description: nil)

      expect(reward).not_to be_valid
      expect(reward.errors[:description]).to include("can't be blank")
    end

    it "rejects a blank description" do
      reward = build(:reward, description: "   ")

      expect(reward).not_to be_valid
      expect(reward.errors[:description]).to include("can't be blank")
    end

    it "requires a reward_type" do
      reward = build(:reward, reward_type: nil)

      expect(reward).not_to be_valid
      expect(reward.errors[:reward_type]).to include("can't be blank")
    end

    it "requires points_cost to be an integer" do
      reward = build(:reward, points_cost: 10.5)

      expect(reward).not_to be_valid
      expect(reward.errors[:points_cost]).to include("must be an integer")
    end

    it "requires points_cost to be greater than or equal to zero" do
      reward = build(:reward, points_cost: -1)

      expect(reward).not_to be_valid
      expect(reward.errors[:points_cost]).to include("must be greater than or equal to 0")
    end

    it "only allows supported reward types" do
      reward = build(:reward, reward_type: "mystery_box")

      expect(reward).not_to be_valid
      expect(reward.errors[:reward_type]).to include("is not included in the list")
    end

    it "requires a fulfillment_provider" do
      reward = build(:reward, fulfillment_provider: nil)

      expect(reward).not_to be_valid
      expect(reward.errors[:fulfillment_provider]).to include("can't be blank")
    end

    it "only allows supported fulfillment providers" do
      reward = build(:reward, fulfillment_provider: "unknown_vendor")

      expect(reward).not_to be_valid
      expect(reward.errors[:fulfillment_provider]).to include("is not included in the list")
    end

  end

  describe "soft delete behavior" do
    it "soft deletes by setting deleted_at and disabling availability" do
      reward = create(:reward, is_available: true, deleted_at: nil)

      reward.soft_delete!

      expect(reward.deleted_at).to be_present
      expect(reward.is_available).to be(false)
    end

    it "restores a soft-deleted reward" do
      reward = create(:reward, is_available: false, deleted_at: 2.days.ago)

      reward.restore!

      expect(reward.deleted_at).to be_nil
    end

    it "blocks hard deletes" do
      reward = create(:reward)

      expect(reward.destroy).to be(false)
      expect(reward.errors[:base]).to include("Hard delete is not allowed for rewards. Use soft_delete! instead.")
      expect(described_class.exists?(reward.id)).to be(true)
    end
  end
end
