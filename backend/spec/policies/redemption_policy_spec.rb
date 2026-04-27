require "rails_helper"

RSpec.describe RedemptionPolicy do
  describe RedemptionPolicy::Scope do
    it "returns only the current user's redemptions" do
      user = create(:user)
      other_user = create(:user)
      own_redemption = create(:user_redemption, user: user)
      create(:user_redemption, user: other_user)

      resolved = RedemptionPolicy::Scope.new(user, User::Redemption).resolve

      expect(resolved).to contain_exactly(own_redemption)
    end

    it "returns no redemptions when user is nil" do
      create(:user_redemption)

      resolved = RedemptionPolicy::Scope.new(nil, User::Redemption).resolve

      expect(resolved).to be_empty
    end
  end

  describe "#index?" do
    let(:user) { create(:user) }

    it "allows authenticated users" do
      policy = RedemptionPolicy.new(user, User::Redemption)

      expect(policy.index?).to be(true)
    end

    it "denies unauthenticated users" do
      policy = RedemptionPolicy.new(nil, User::Redemption)

      expect(policy.index?).to be(false)
    end
  end

  describe "#create?" do
    let(:user) { create(:user) }

    it "allows authenticated users" do
      policy = RedemptionPolicy.new(user, User::Redemption)

      expect(policy.create?).to be(true)
    end

    it "denies unauthenticated users" do
      policy = RedemptionPolicy.new(nil, User::Redemption)

      expect(policy.create?).to be(false)
    end
  end
end
