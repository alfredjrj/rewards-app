class Reward < ApplicationRecord
  include PgSearch::Model

  TYPES = %w[vip_experience free_item secret_menu].freeze
  has_many :redemptions,
           class_name: "User::Redemption",
           inverse_of: :reward,
           dependent: :restrict_with_error

  validates :title, :reward_type, presence: true
  validates :points_cost, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :reward_type, inclusion: { in: TYPES }

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
end
