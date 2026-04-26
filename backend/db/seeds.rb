user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password123"
  u.password_confirmation = "password123"
end
puts "User created: #{user.email}"

point_transactions_seed = [
  { amount: 500, kind: "earn", reason_code: "signup_bonus", reason: "Initial signup reward", idempotency_key: "seed-signup-bonus" },
  { amount: 250, kind: "earn", reason_code: "purchase", reason: "Points earned from first purchase", idempotency_key: "seed-first-purchase" },
  { amount: -100, kind: "redeem", reason_code: "reward_redemption", reason: "Redeemed Free Coffee", idempotency_key: "seed-redeem-coffee" },
  { amount: 120, kind: "earn", reason_code: "referral_bonus", reason: "Referral reward", idempotency_key: "seed-referral-bonus" },
  { amount: -80, kind: "expiry", reason_code: "expiry", reason: "Monthly point expiry adjustment", idempotency_key: "seed-monthly-expiry" }
]

running_balance = 0
point_transactions_seed.each do |attrs|
  running_balance += attrs[:amount]
  tx = User::PointTransaction.find_or_initialize_by(user: user, idempotency_key: attrs[:idempotency_key])
  tx.update!(attrs.merge(running_balance: running_balance))
  puts "Point transaction seeded: #{tx.kind} #{tx.amount} (balance: #{tx.running_balance})"
end

rewards_data = [
  {
    title: "Free Coffee",
    description: "Redeem for a free cup of coffee at participating locations.",
    points_cost: 100,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "$5 Gift Card",
    description: "Get a $5 gift card to use at any partner store.",
    points_cost: 250,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Movie Ticket",
    description: "Enjoy one free movie ticket at select theaters.",
    points_cost: 500,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Spa Voucher",
    description: "Treat yourself to a relaxing spa session.",
    points_cost: 1000,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Limited Hoodie",
    description: "Exclusive branded hoodie from the rewards store.",
    points_cost: 1800,
    reward_type: "secret_menu",
    is_available: false
  },
  {
    title: "Priority Support Pass",
    description: "Get priority customer support for one month.",
    points_cost: 220,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Mystery Snack Box",
    description: "Receive a curated snack box from our secret menu.",
    points_cost: 320,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Breakfast Combo",
    description: "Redeem for one breakfast combo at participating locations.",
    points_cost: 180,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Lounge Access Day Pass",
    description: "Access premium lounge amenities for one day.",
    points_cost: 900,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Secret Menu Burger",
    description: "Unlock a limited-time off-menu burger.",
    points_cost: 450,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Dessert",
    description: "Choose any complimentary dessert from select partners.",
    points_cost: 150,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Chef's Table Invite",
    description: "Exclusive chef's table experience for one guest.",
    points_cost: 2400,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Hidden Ramen Night",
    description: "Invite-only ramen tasting from the secret menu lineup.",
    points_cost: 1300,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Smoothie",
    description: "Redeem for one signature smoothie.",
    points_cost: 140,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "VIP Event Seating",
    description: "Reserved front-row seating at selected events.",
    points_cost: 2700,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Secret Tasting Flight",
    description: "Try an unreleased tasting flight curated by experts.",
    points_cost: 1650,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Sandwich",
    description: "Redeem for one handcrafted sandwich.",
    points_cost: 200,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Backstage Tour",
    description: "Behind-the-scenes tour at a partner venue.",
    points_cost: 2100,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Chef's Secret Bento",
    description: "Limited bento available only through rewards members.",
    points_cost: 980,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Pizza Slice",
    description: "Redeem for one premium pizza slice.",
    points_cost: 120,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "VIP Fast Track Entry",
    description: "Skip lines with express entry at selected venues.",
    points_cost: 1100,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Hidden Matcha Menu",
    description: "Access secret matcha drinks not listed publicly.",
    points_cost: 760,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Salad Bowl",
    description: "Redeem for one premium salad bowl.",
    points_cost: 230,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "VIP Studio Session",
    description: "Private studio class with priority booking.",
    points_cost: 1950,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Secret Off-Menu Pasta",
    description: "Special off-menu pasta crafted daily.",
    points_cost: 870,
    reward_type: "secret_menu",
    is_available: true
  }
]

rewards_data.each do |attrs|
  reward = Reward.find_or_initialize_by(title: attrs[:title])
  reward.update!(attrs)
  puts "Reward seeded: #{reward.title} (#{reward.points_cost} points)"
end

puts "Seeding complete!"
