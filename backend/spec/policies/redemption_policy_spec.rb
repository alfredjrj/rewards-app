require "rails_helper"

RSpec.describe RedemptionPolicy do
  describe "#create?" do
    let(:user) { create(:user) }

    it "allows authenticated users" do
      policy = described_class.new(user, User::Redemption)

      expect(policy.create?).to be(true)
    end

    it "denies unauthenticated users" do
      policy = described_class.new(nil, User::Redemption)

      expect(policy.create?).to be(false)
    end
  end
end
