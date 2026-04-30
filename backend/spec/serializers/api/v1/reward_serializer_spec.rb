require "rails_helper"

RSpec.describe Api::V1::RewardSerializer do
  it "serializes reward payload" do
    reward = create(
      :reward,
      title: "Coffee Voucher",
      description: "Fresh brew",
      points_cost: 100,
      reward_type: "free_item",
      is_available: true
    )

    payload = Api::V1::RewardSerializer.call(reward: reward)

    expect(payload).to eq(
      data: {
        id: reward.id,
        title: "Coffee Voucher",
        description: "Fresh brew",
        points_cost: 100,
        reward_type: "free_item",
        fulfillment_provider: reward.fulfillment_provider,
        is_available: true
      }
    )
  end

  describe Api::V1::RewardSerializer::Collection do
    it "serializes reward collection payload" do
      first = create(:reward, title: "Coffee Voucher", points_cost: 100, reward_type: "free_item")
      second = create(:reward, title: "VIP Pass", points_cost: 300, reward_type: "vip_experience")

      payload = Api::V1::RewardSerializer::Collection.call(rewards: [ first, second ])

      expect(payload).to eq(
        data: [
          {
            id: first.id,
            title: "Coffee Voucher",
            description: first.description,
            points_cost: 100,
            reward_type: "free_item",
            fulfillment_provider: first.fulfillment_provider,
            is_available: first.is_available
          },
          {
            id: second.id,
            title: "VIP Pass",
            description: second.description,
            points_cost: 300,
            reward_type: "vip_experience",
            fulfillment_provider: second.fulfillment_provider,
            is_available: second.is_available
          }
        ]
      )
    end
  end
end
