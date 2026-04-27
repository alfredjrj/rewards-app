class UserRedemptionsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless RedemptionPolicy.new(current_user, :redemption).index?

    stream_from "user_redemptions:#{current_user.id}"
  end
end
