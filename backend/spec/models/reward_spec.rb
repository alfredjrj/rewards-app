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
  end
end
