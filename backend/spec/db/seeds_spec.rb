require "rails_helper"

RSpec.describe "db/seeds.rb" do
  def load_seeds
    load Rails.root.join("db/seeds.rb")
  end

  it "seeds demo user, rewards, and linked redemption transactions" do
    load_seeds

    user = User.find_by(email: "demo@example.com")
    point_transactions = User::PointTransaction.where(user: user).order(:created_at, :id)
    redemptions = User::Redemption.where(user: user)
    redeem_transactions = point_transactions.where(kind: "redeem")

    expect(user).to be_present
    expect(user.admin).to be(true)
    expect(Reward.count).to eq(35)
    expect(redemptions.count).to eq(11)
    expect(point_transactions.count).to eq(15)
    expect(redeem_transactions.count).to eq(11)
    expect(point_transactions.last.running_balance).to eq(810)
    expect(redeem_transactions.pluck(:source_type).uniq).to eq([ "User::Redemption" ])
    expect(
      redeem_transactions.pluck(:source_id).sort
    ).to eq(redemptions.pluck(:id).sort)

    cumulative_balance = 0
    point_transactions.each do |transaction|
      cumulative_balance += transaction.amount
      expect(transaction.running_balance).to eq(cumulative_balance)
      expect(transaction.running_balance).to be >= 0
    end
  end

  it "is idempotent when loaded twice" do
    load_seeds
    load_seeds

    user = User.find_by(email: "demo@example.com")
    point_transactions = User::PointTransaction.where(user: user)
    redemptions = User::Redemption.where(user: user)

    expect(Reward.count).to eq(35)
    expect(point_transactions.count).to eq(15)
    expect(redemptions.count).to eq(11)
  end
end
