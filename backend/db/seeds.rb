user = User.find_or_initialize_by(email: "demo@example.com")
user.assign_attributes(
  password: "password123",
  password_confirmation: "password123",
  admin: true
)
user.save!
puts "User created: #{user.email}"

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
  },
  {
    title: "Artisan Pastry Box",
    description: "Seasonal pastries from local baker partners.",
    points_cost: 340,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Sunset Harbor Cruise",
    description: "Evening cruise with light refreshments.",
    points_cost: 1850,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Midnight Cocoa Flight",
    description: "Secret-menu tasting of single-origin cocoas.",
    points_cost: 620,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Free Iced Tea Refill",
    description: "Unlimited iced tea refills for one visit.",
    points_cost: 95,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Yoga Workshop Weekend",
    description: "Two-day beginner-friendly yoga intensive.",
    points_cost: 1420,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Underground Vinyl Listening",
    description: "Private session with rare pressings from the vault.",
    points_cost: 1180,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Family Picnic Basket",
    description: "Curated picnic for four at partner parks.",
    points_cost: 410,
    reward_type: "free_item",
    is_available: true
  },
  {
    title: "Concierge Dinner Booking",
    description: "Priority reservations at partner restaurants for one month.",
    points_cost: 1750,
    reward_type: "vip_experience",
    is_available: true
  },
  {
    title: "Whisper Dessert Pairing",
    description: "Off-menu dessert courses with paired cordials.",
    points_cost: 990,
    reward_type: "secret_menu",
    is_available: true
  },
  {
    title: "Eco Tote & Travel Mug",
    description: "Reusable tote and insulated mug from the rewards shop.",
    points_cost: 280,
    reward_type: "free_item",
    is_available: true
  }
]

rewards_data.each do |attrs|
  reward = Reward.find_or_initialize_by(title: attrs[:title])
  reward.update!(attrs)
  puts "Reward seeded: #{reward.title} (#{reward.points_cost} points)"
end

running_balance = 0

base_point_transactions_seed = [
  { amount: 4000, kind: "earn", reason_code: "signup_bonus", reason: "Initial signup reward", idempotency_key: "seed-signup-bonus" },
  { amount: 250, kind: "earn", reason_code: "purchase", reason: "Points earned from first purchase", idempotency_key: "seed-first-purchase" },
  { amount: 2000, kind: "earn", reason_code: "referral_bonus", reason: "Referral reward", idempotency_key: "seed-referral-bonus" },
  { amount: -80, kind: "expiry", reason_code: "expiry", reason: "Monthly point expiry adjustment", idempotency_key: "seed-monthly-expiry" }
]

base_point_transactions_seed.each do |attrs|
  running_balance += attrs[:amount]
  tx = User::PointTransaction.find_or_initialize_by(user: user, idempotency_key: attrs[:idempotency_key])
  tx.update!(attrs.merge(running_balance: running_balance))
  puts "Point transaction seeded: #{tx.kind} #{tx.amount} (balance: #{tx.running_balance})"
end

user_redemptions_seed = [
  { reward_title: "Free Coffee", idempotency_key: "seed-redeem-001" },
  { reward_title: "$5 Gift Card", idempotency_key: "seed-redeem-002" },
  { reward_title: "Free Breakfast Combo", idempotency_key: "seed-redeem-003" },
  { reward_title: "Free Dessert", idempotency_key: "seed-redeem-004" },
  { reward_title: "Free Smoothie", idempotency_key: "seed-redeem-005" },
  { reward_title: "Free Sandwich", idempotency_key: "seed-redeem-006" },
  { reward_title: "Priority Support Pass", idempotency_key: "seed-redeem-007" },
  { reward_title: "Free Salad Bowl", idempotency_key: "seed-redeem-008" },
  { reward_title: "Free Pizza Slice", idempotency_key: "seed-redeem-009" },
  { reward_title: "Mystery Snack Box", idempotency_key: "seed-redeem-010" },
  { reward_title: "Secret Menu Burger", idempotency_key: "seed-redeem-011" }
]

user_redemptions_seed.each do |attrs|
  reward = Reward.find_by!(title: attrs[:reward_title])
  redemption_key = "seed-user-redemption-#{attrs[:idempotency_key]}"

  redemption = User::Redemption.find_or_initialize_by(user: user, idempotency_key: redemption_key)
  redemption.update!(
    reward: reward,
    points_cost_snapshot: reward.points_cost,
    status: "completed"
  )

  redeem_amount = -reward.points_cost
  running_balance += redeem_amount

  tx = User::PointTransaction.find_or_initialize_by(user: user, idempotency_key: attrs[:idempotency_key])
  tx.update!(
    amount: redeem_amount,
    running_balance: running_balance,
    kind: "redeem",
    reason_code: "reward_redemption",
    reason: "Redeemed #{reward.title}",
    source: redemption
  )

  puts "Redemption seeded: #{redemption.id} #{reward.title} (balance: #{running_balance})"
end

puts "Final seeded points balance: #{running_balance}"
puts "Seeding complete!"
