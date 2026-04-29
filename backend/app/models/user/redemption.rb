class User::Redemption < ApplicationRecord
  STATUSES = %w[processing completed failed cancelled].freeze

  belongs_to :user
  belongs_to :reward
  has_many :audits,
           class_name: "User::RedemptionAudit",
           foreign_key: :user_redemption_id,
           inverse_of: :redemption,
           dependent: :destroy
  has_many :point_transactions,
           as: :source,
           class_name: "User::PointTransaction",
           inverse_of: :source,
           dependent: :nullify

  validates :points_cost_snapshot, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :idempotency_key, presence: true, uniqueness: { scope: :user_id }

  after_create :log_created_audit
  after_update :log_updated_audit

  private

  def log_created_audit
    User::Redemptions::Audit.record(
      redemption: self,
      change_reason: "created",
      change_source: "model_callback",
      point_transaction: related_point_transaction
    )
  end

  def log_updated_audit
    User::Redemptions::Audit.record(
      redemption: self,
      change_reason: "updated",
      change_source: "model_callback",
      point_transaction: related_point_transaction
    )
  end

  def related_point_transaction
    point_transactions.order(id: :desc).first
  end
end
