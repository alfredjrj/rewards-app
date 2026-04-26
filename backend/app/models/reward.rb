class Reward < ApplicationRecord
  include PgSearch::Model

  TYPES = %w[vip_experience free_item secret_menu].freeze

  validates :title, :reward_type, presence: true
  validates :points_cost, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :reward_type, inclusion: { in: TYPES }

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
