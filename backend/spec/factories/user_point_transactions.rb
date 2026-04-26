FactoryBot.define do
  factory :user_point_transaction, class: "User::PointTransaction" do
    association :user
    amount { 100 }
    running_balance { 100 }
    kind { "earn" }
    reason_code { "signup_bonus" }
    sequence(:idempotency_key) { |n| "ptx-#{n}" }
    reason { "Welcome bonus" }
  end
end
