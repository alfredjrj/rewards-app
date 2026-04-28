require "rails_helper"

RSpec.describe UserRedemptionsChannel, type: :channel do
  describe "#subscribed" do
    let(:user) { create(:user) }

    before do
      stub_connection current_user: user
    end

    it "subscribes and streams for authorized user" do
      subscribe

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from("user_redemptions:#{user.id}")
    end

    it "rejects subscription when policy denies access" do
      denied_policy = instance_double(User::RedemptionPolicy, index?: false)
      allow(User::RedemptionPolicy).to receive(:new).with(user, User::Redemption).and_return(denied_policy)

      subscribe

      expect(subscription).to be_rejected
    end
  end
end
