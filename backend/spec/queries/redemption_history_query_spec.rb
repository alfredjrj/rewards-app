require "rails_helper"

RSpec.describe RedemptionHistoryQuery do
  it "filters by status" do
    user = create(:user)
    reward = create(:reward)
    create(:user_redemption, user: user, reward: reward, status: "completed")
    create(:user_redemption, user: user, reward: reward, status: "cancelled")

    params = { filter: { status: "completed" } }
    results = RedemptionHistoryQuery.new(User::Redemption.all, params).call

    expect(results.pluck(:status).uniq).to eq([ "completed" ])
  end

  it "filters by points range using gte and lte" do
    user = create(:user)
    reward = create(:reward)
    create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 100)
    middle = create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 250)
    create(:user_redemption, user: user, reward: reward, points_cost_snapshot: 500)

    params = { filter: { points: { gte: 150, lte: 300 } } }
    results = RedemptionHistoryQuery.new(User::Redemption.all, params).call

    expect(results.pluck(:id)).to eq([ middle.id ])
  end

  it "sorts by created_at descending with -field" do
    user = create(:user)
    reward = create(:reward)
    older = create(:user_redemption, user: user, reward: reward, created_at: 2.days.ago)
    newer = create(:user_redemption, user: user, reward: reward, created_at: 1.day.ago)

    params = { sort: "-created_at" }
    results = RedemptionHistoryQuery.new(User::Redemption.all, params).call

    expect(results.pluck(:id)).to eq([ newer.id, older.id ])
  end
end
