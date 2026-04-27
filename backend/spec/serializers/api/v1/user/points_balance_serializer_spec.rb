require "rails_helper"

RSpec.describe Api::V1::User::PointsBalanceSerializer do
  it "serializes points balance payload" do
    payload = Api::V1::User::PointsBalanceSerializer.call(points_balance: 690)

    expect(payload).to eq(
      data: {
        points_balance: 690
      }
    )
  end
end
