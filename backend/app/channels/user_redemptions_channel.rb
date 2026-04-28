class UserRedemptionsChannel < ApplicationCable::Channel
  def subscribed
    return reject unless User::RedemptionPolicy.new(current_user, User::Redemption).index?

    stream_from "user_redemptions:#{current_user.id}"
  end
end
