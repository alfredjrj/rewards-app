class User::Redemption < ApplicationRecord
  STATUSES = %w[processing completed failed cancelled].freeze

  # Not persisted — set by callers before save so audit callbacks carry provenance (no thread globals).
  attr_accessor :change_source_origin, :change_source_metadata

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

  def assign_change_source_origin(change_source_origin:, change_source_metadata: {})
    self.change_source_origin = change_source_origin.to_s
    self.change_source_metadata = change_source_metadata.deep_stringify_keys
  end

  # after_save/after_commit on :update do not run reliably for :update when create+update share one transaction;
  # after_create/after_update run per save and keep snapshot order (e.g. processing, then completed).
  after_create :record_audit_after_create
  after_update :record_audit_after_update

  private

  def record_audit_after_create
    write_audit_row(change_reason: "created")
  end

  def record_audit_after_update
    write_audit_row(change_reason: "updated")
  end

  def write_audit_row(change_reason:)
    User::Redemptions::Audit.record(
      redemption: self,
      change_reason: change_reason,
      change_source_origin: change_source_origin,
      point_transaction: related_point_transaction
    )
  end

  def related_point_transaction
    point_transactions.order(id: :desc).first
  end
end
