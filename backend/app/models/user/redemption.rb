class User::Redemption < ApplicationRecord
  STATUSES = %w[processing completed failed cancelled].freeze

  belongs_to :user
  belongs_to :reward

  validates :points_cost_snapshot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true, uniqueness: { scope: :user_id }
end
