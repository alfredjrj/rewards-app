class Api::V1::User::RedemptionHistoryCollectionSerializer
  def self.call(redemptions:)
    redemptions.map do |redemption|
      Api::V1::User::RedemptionHistorySerializer.call(redemption: redemption)
    end
  end
end
