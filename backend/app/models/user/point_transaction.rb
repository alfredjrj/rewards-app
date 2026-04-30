class User::PointTransaction < ApplicationRecord
  self.table_name = "user_point_transactions"

  ALLOWED_SOURCE_TYPES = %w[Reward User::Redemption].freeze
  KINDS = %w[earn redeem adjustment expiry reversal].freeze
  REASON_CODES = %w[
    purchase
    reward_redemption
    manual_adjustment
    expiry
    reversal
    signup_bonus
    referral_bonus
    admin_correction
  ].freeze

  belongs_to :user, class_name: "User", inverse_of: :point_transactions
  belongs_to :source, polymorphic: true, optional: true

  validates :amount, numericality: { only_integer: true, other_than: 0 }
  validates :running_balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :kind, inclusion: { in: KINDS }
  validates :reason_code, inclusion: { in: REASON_CODES }
  validates :source_type, inclusion: { in: ALLOWED_SOURCE_TYPES }, allow_nil: true
  validates :idempotency_key, presence: true, uniqueness: { scope: :user_id }

  before_destroy :prevent_destroy

  def readonly?
    persisted?
  end

  private

  def prevent_destroy
    raise ActiveRecord::ReadOnlyRecord, "#{self.class.name} is append-only and cannot be deleted"
  end
end
