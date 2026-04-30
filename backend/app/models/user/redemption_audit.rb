class User::RedemptionAudit < ApplicationRecord
  CHANGE_REASONS = %w[created updated].freeze
  # system — model callbacks, specs, seeds, or any write without api_request / background_job provenance
  CHANGE_SOURCES = %w[api_request background_job system].freeze

  belongs_to :redemption, class_name: "User::Redemption", foreign_key: :user_redemption_id, inverse_of: :audits
  belongs_to :user
  belongs_to :reward
  belongs_to :point_transaction, class_name: "User::PointTransaction", optional: true

  validates :request_id, presence: true
  validates :change_source_origin, presence: true, inclusion: { in: CHANGE_SOURCES }
  validates :change_reason, presence: true, inclusion: { in: CHANGE_REASONS }
  validates :snapshot, presence: true
end
