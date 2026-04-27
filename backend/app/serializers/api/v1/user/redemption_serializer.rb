class Api::V1::User::RedemptionSerializer
  def self.call(redemption:, points_balance:)
    {
      id: redemption.id,
      reward_id: redemption.reward_id,
      points_cost_snapshot: redemption.points_cost_snapshot,
      status: redemption.status,
      points_balance: points_balance
    }
  end
end
