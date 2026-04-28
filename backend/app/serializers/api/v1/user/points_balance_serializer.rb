class Api::V1::User::PointsBalanceSerializer
  def self.call(points_balance:, points_pending_redemption:, points_available:)
    {
      data: {
        points_balance: points_balance,
        points_pending_redemption: points_pending_redemption,
        points_available: points_available
      }
    }
  end
end
