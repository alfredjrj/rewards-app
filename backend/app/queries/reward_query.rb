class RewardQuery < BaseQuery
  ALLOWED_REWARD_TYPES = %w[free_item vip_experience secret_menu].freeze

  FILTERABLE = {
    "query" => :filter_query,
    "reward_types" => :filter_reward_types
  }.freeze
  RANGE_FILTERS = {
    "points" => {
      field: "points_cost",
      type: :integer,
      operators: %w[gte lte]
    }
  }.freeze

  SORTABLE = {
    "title" => %i[asc desc],
    "points_cost" => %i[asc desc],
    "created_at" => %i[asc desc]
  }.freeze

  private

  def filter_query(current_scope, value)
    query = value.to_s.strip
    query.present? ? current_scope.search_text(query) : current_scope
  end

  def filter_reward_types(current_scope, value)
    allowed_types = normalized_reward_types(value)
    allowed_types.any? ? current_scope.for_types(allowed_types) : current_scope
  end

  def normalized_reward_types(value)
    clean_string_array(value).select { |type| ALLOWED_REWARD_TYPES.include?(type) }
  end
end
