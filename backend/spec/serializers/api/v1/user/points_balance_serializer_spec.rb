require "rails_helper"

RSpec.describe Api::V1::User::PointsBalanceSerializer do
  it "serializes points balance payload" do
    payload = Api::V1::User::PointsBalanceSerializer.call(
      points_balance: 690,
      points_pending_redemption: 50,
      points_available: 640
    )

    expect(payload).to eq(
      data: {
        points_balance: 690,
        points_pending_redemption: 50,
        points_available: 640
      }
    )
  end
end
