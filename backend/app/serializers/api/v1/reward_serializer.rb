class Api::V1::RewardSerializer
  def self.call(reward:)
    {
      data: {
        id: reward.id,
        title: reward.title,
        description: reward.description,
        points_cost: reward.points_cost,
        reward_type: reward.reward_type,
        is_available: reward.is_available
      }
    }
  end

  class Collection
    def self.call(rewards:)
      { data: rewards.map { |reward| Api::V1::RewardSerializer.call(reward: reward)[:data] } }
    end
  end
end
