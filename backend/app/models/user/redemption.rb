class User::Redemption < ApplicationRecord
  include AASM

  STATUSES = %w[processing completed failed cancelled].freeze

  belongs_to :user
  belongs_to :reward
  # Audit rows are retained forever; redemptions are not hard-deleted in normal flows.
  has_many :audits,
           class_name: "User::RedemptionAudit",
           foreign_key: :user_redemption_id,
           inverse_of: :redemption,
           dependent: :restrict_with_error
  has_many :point_transactions,
           as: :source,
           class_name: "User::PointTransaction",
           inverse_of: :source,
           dependent: :nullify

  validates :points_cost_snapshot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true, uniqueness: { scope: :user_id }

  def finalized?
    completed? || failed? || cancelled?
  end

  aasm column: :status, whiny_transitions: false do
    state :processing, initial: true
    state :completed
    state :failed
    state :cancelled

    event :complete do
      transitions from: :processing, to: :completed
    end

    event :fail do
      transitions from: :processing, to: :failed
    end

    event :cancel do
      transitions from: :processing, to: :cancelled
    end
  end

end
