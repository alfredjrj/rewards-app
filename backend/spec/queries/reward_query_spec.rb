require "rails_helper"

RSpec.describe RewardQuery do
  it "filters by query text using reward search scope" do
    create(:reward, title: "Coffee Voucher", description: "Fresh roast")
    create(:reward, title: "Movie Ticket", description: "Cinema night")

    params = { filter: { query: "coffee" } }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "Coffee Voucher" ])
  end

  it "filters by reward_types and ignores invalid values" do
    create(:reward, title: "Coffee Voucher", reward_type: "free_item")
    create(:reward, title: "Movie Ticket", reward_type: "vip_experience")
    create(:reward, title: "Secret Burger", reward_type: "secret_menu")

    params = { filter: { reward_types: [ "free_item", "invalid_type" ] } }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "Coffee Voucher" ])
  end

  it "filters by points lte" do
    create(:reward, title: "Low Cost", points_cost: 100)
    create(:reward, title: "High Cost", points_cost: 500)

    params = { filter: { points: { lte: 150 } } }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "Low Cost" ])
  end

  it "filters by points gte" do
    create(:reward, title: "Low Cost", points_cost: 100)
    create(:reward, title: "High Cost", points_cost: 500)

    params = { filter: { points: { gte: 200 } } }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "High Cost" ])
  end

  it "filters by points range gte and lte" do
    create(:reward, title: "Low Cost", points_cost: 100)
    create(:reward, title: "Mid Cost", points_cost: 250)
    create(:reward, title: "High Cost", points_cost: 500)

    params = { filter: { points: { gte: 150, lte: 300 } } }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "Mid Cost" ])
  end

  it "sorts ascending when sort uses field name" do
    create(:reward, title: "B Item", points_cost: 200)
    create(:reward, title: "A Item", points_cost: 100)

    params = { sort: "title" }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "A Item", "B Item" ])
  end

  it "sorts descending when sort uses -field" do
    create(:reward, title: "B Item", points_cost: 200)
    create(:reward, title: "A Item", points_cost: 100)

    params = { sort: "-points_cost" }
    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "B Item", "A Item" ])
  end

  it "ignores unknown sort fields" do
    first_reward = create(:reward, title: "First", points_cost: 100)
    second_reward = create(:reward, title: "Second", points_cost: 200)

    params = { sort: "unknown_field" }
    results = RewardQuery.new(Reward.where(id: [ first_reward.id, second_reward.id ]).order(:id), params).call

    expect(results.pluck(:id)).to eq([ first_reward.id, second_reward.id ])
  end

  it "applies filters and sort together" do
    create(:reward, title: "Coffee Basic", reward_type: "free_item", points_cost: 100)
    create(:reward, title: "Coffee Deluxe", reward_type: "free_item", points_cost: 300)
    create(:reward, title: "VIP Coffee", reward_type: "vip_experience", points_cost: 500)

    params = {
      filter: { query: "coffee", reward_types: [ "free_item" ] },
      sort: "-points_cost"
    }

    results = RewardQuery.new(Reward.all, params).call

    expect(results.pluck(:title)).to eq([ "Coffee Deluxe", "Coffee Basic" ])
  end
end
