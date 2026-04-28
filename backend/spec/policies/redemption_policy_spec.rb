require "rails_helper"

RSpec.describe User::RedemptionPolicy do
  describe User::RedemptionPolicy::Scope do
    it "returns only the current user's redemptions" do
      user = create(:user)
      other_user = create(:user)
      own_redemption = create(:user_redemption, user: user)
      create(:user_redemption, user: other_user)

      resolved = User::RedemptionPolicy::Scope.new(user, User::Redemption).resolve

      expect(resolved).to contain_exactly(own_redemption)
    end

    it "returns no redemptions when user is nil" do
      create(:user_redemption)

      resolved = User::RedemptionPolicy::Scope.new(nil, User::Redemption).resolve

      expect(resolved).to be_empty
    end
  end

  describe "#index?" do
    let(:user) { create(:user) }

    it "allows authenticated users" do
      policy = User::RedemptionPolicy.new(user, User::Redemption)

      expect(policy.index?).to be(true)
    end

    it "denies unauthenticated users" do
      policy = User::RedemptionPolicy.new(nil, User::Redemption)

      expect(policy.index?).to be(false)
    end
  end

  describe "#create?" do
    let(:user) { create(:user) }

    it "denies unauthenticated users" do
      reward = create(:reward, is_available: true)
      redemption = build(:user_redemption, user: user, reward: reward)
      policy = User::RedemptionPolicy.new(nil, redemption)

      expect(policy.create?).to be(false)
    end

    it "allows available reward redemption records for the same user" do
      reward = create(:reward, is_available: true)
      redemption = build(:user_redemption, user: user, reward: reward)
      policy = User::RedemptionPolicy.new(user, redemption)

      expect(policy.create?).to be(true)
    end

    it "denies unavailable reward redemption records" do
      reward = create(:reward, is_available: false)
      redemption = build(:user_redemption, user: user, reward: reward)
      policy = User::RedemptionPolicy.new(user, redemption)

      expect(policy.create?).to be(false)
    end

    it "denies redemption records for another user" do
      other_user = create(:user)
      reward = create(:reward, is_available: true)
      redemption = build(:user_redemption, user: other_user, reward: reward)
      policy = User::RedemptionPolicy.new(user, redemption)

      expect(policy.create?).to be(false)
    end
  end
end
