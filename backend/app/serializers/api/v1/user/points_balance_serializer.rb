class Api::V1::User::PointsBalanceSerializer
  def self.call(points_balance:)
    {
      data: {
        points_balance: points_balance
      }
    }
  end
end
