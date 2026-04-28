class User::Points::AvailableBalance
  def self.call(user:)
    new(user: user).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    points_balance = latest_points_balance
    points_pending_redemption = pending_redemption_points
    {
      points_balance: points_balance,
      points_pending_redemption: points_pending_redemption,
      points_available: [ points_balance - points_pending_redemption, 0 ].max
    }
  end

  private

  attr_reader :user

  def latest_points_balance
    user
      .point_transactions
      .order(created_at: :desc, id: :desc)
      .pick(:running_balance) || 0
  end

  def pending_redemption_points
    user
      .redemptions
      .where(status: "processing")
      .sum(:points_cost_snapshot)
  end
end
