class Reward < ApplicationRecord
  include PgSearch::Model

  TYPES = %w[vip_experience free_item secret_menu].freeze
  FULFILLMENT_PROVIDERS = %w[internal ticketmaster].freeze
  has_many :redemptions,
           class_name: "User::Redemption",
           inverse_of: :reward,
           dependent: :restrict_with_error

  validates :title, :description, :reward_type, :fulfillment_provider, presence: true
  validates :points_cost, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :reward_type, inclusion: { in: TYPES }
  validates :fulfillment_provider, inclusion: { in: FULFILLMENT_PROVIDERS }
  before_destroy :prevent_hard_delete

  scope :active, -> { where(deleted_at: nil) }
  scope :soft_deleted, -> { where.not(deleted_at: nil) }
  scope :for_types, ->(types) { where(reward_type: types) if types.present? }
  scope :by_points_cost, lambda { |min: nil, max: nil|
    scoped = all
    scoped = scoped.where("points_cost >= ?", min) if min.present?
    scoped = scoped.where("points_cost <= ?", max) if max.present?
    scoped
  }

  pg_search_scope :search_text,
                  against: {
                    title: "A",
                    description: "B"
                  },
                  using: {
                    tsearch: {
                      dictionary: "english",
                      prefix: true
                    }
                  }

  def sync_fulfillment?
    fulfillment_provider == "internal"
  end

  def soft_delete!
    update!(deleted_at: Time.current, is_available: false)
  end

  def restore!
    update!(deleted_at: nil)
  end

  private

  def prevent_hard_delete
    errors.add(:base, "Hard delete is not allowed for rewards. Use soft_delete! instead.")
    throw :abort
  end
end
