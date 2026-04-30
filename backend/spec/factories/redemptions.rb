FactoryBot.define do
  factory :user_redemption, class: "User::Redemption" do
    association :user
    association :reward
    points_cost_snapshot { reward.points_cost }
    status { "completed" }
    sequence(:idempotency_key) { |n| format("10000000-0000-0000-0000-%012d", n) }

    after(:build) do |redemption|
      redemption.assign_change_source_origin(
        change_source_origin: "system",
        change_source_metadata: { "test" => true }
      )
    end
  end
end
