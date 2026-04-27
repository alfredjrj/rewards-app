require "rails_helper"

RSpec.describe Api::V1::User::RedemptionSerializer do
  it "serializes create response payload" do
    redemption = create(:user_redemption, points_cost_snapshot: 120, status: "completed")

    payload = Api::V1::User::RedemptionSerializer.call(
      redemption: redemption,
      points_balance: 380
    )

    expect(payload).to eq(
      id: redemption.id,
      reward_id: redemption.reward_id,
      points_cost_snapshot: 120,
      status: "completed",
      points_balance: 380
    )
  end
end
