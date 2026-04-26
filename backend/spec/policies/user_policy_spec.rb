require "rails_helper"

RSpec.describe UserPolicy do
  describe "#show?" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }

    it "allows access to self" do
      policy = described_class.new(user, user)

      expect(policy.show?).to be(true)
    end

    it "denies access to another user record" do
      policy = described_class.new(user, other_user)

      expect(policy.show?).to be(false)
    end

    it "denies access without an authenticated user" do
      policy = described_class.new(nil, user)

      expect(policy.show?).to be(false)
    end
  end
end
