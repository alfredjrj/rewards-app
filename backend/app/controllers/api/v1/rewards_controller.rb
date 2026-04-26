class Api::V1::RewardsController < AuthenticationController
  def index
    unless RewardPolicy.new(current_user, :reward).index?
      render json: { error: "Not authorized" }, status: :forbidden
      return
    end

    render json: []
  end
end
