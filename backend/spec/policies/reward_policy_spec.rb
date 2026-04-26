require "rails_helper"

RSpec.describe RewardPolicy do
  subject(:policy) { described_class.new(user, :reward) }

  context "when user is authenticated" do
    let(:user) { build(:user) }

    it "allows index" do
      expect(policy.index?).to be(true)
    end
  end

  context "when user is not authenticated" do
    let(:user) { nil }

    it "denies index" do
      expect(policy.index?).to be(false)
    end
  end
end
