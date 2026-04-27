class Api::V1::User::RedemptionSerializer
  def self.call(redemption:)
    {
      data: {
        id: redemption.id,
        reward_id: redemption.reward_id,
        points_cost_snapshot: redemption.points_cost_snapshot,
        status: redemption.status
      }
    }
  end

  class Status
    def self.call(request_id:, status:, redemption: nil, reward_id: nil, error: nil)
      {
        data: {
          request_id: request_id,
          id: redemption&.id,
          reward_id: redemption&.reward_id || reward_id,
          points_cost_snapshot: redemption&.points_cost_snapshot,
          status: status,
          error: error
        }.compact
      }
    end
  end
end
