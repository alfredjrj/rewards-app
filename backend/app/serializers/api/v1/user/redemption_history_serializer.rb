class Api::V1::User::RedemptionHistorySerializer
  def self.call(redemption:)
    {
      id: redemption.id,
      reward_id: redemption.reward_id,
      reward_title: redemption.reward&.title,
      points_cost_snapshot: redemption.points_cost_snapshot,
      status: redemption.status,
      created_at: redemption.created_at
    }
  end
end
