FactoryBot.define do
  factory :user_redemption, class: "User::Redemption" do
    association :user
    association :reward
    points_cost_snapshot { reward.points_cost }
    status { "completed" }
    sequence(:idempotency_key) { |n| format("10000000-0000-0000-0000-%012d", n) }
  end
end
