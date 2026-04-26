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

  describe "scope" do
    let!(:available_reward) { create(:reward, title: "A Reward", is_available: true) }
    let!(:unavailable_reward) { create(:reward, title: "B Reward", is_available: false) }

    context "when user is authenticated" do
      let(:user) { create(:user) }

      it "returns only available rewards ordered by title" do
        result = described_class::Scope.new(user, Reward).resolve

        expect(result).to eq([ available_reward ])
      end
    end

    context "when user is not authenticated" do
      let(:user) { nil }

      it "returns no records" do
        result = described_class::Scope.new(user, Reward).resolve

        expect(result).to be_empty
      end
    end
  end
end
