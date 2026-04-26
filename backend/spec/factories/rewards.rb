FactoryBot.define do
  factory :reward do
    sequence(:title) { |n| "Reward #{n}" }
    description { "Reward description" }
    points_cost { 100 }
    reward_type { "free_item" }
    is_available { true }
  end
end
