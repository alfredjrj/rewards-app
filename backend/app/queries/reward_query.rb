class RewardQuery < BaseQuery
  ALLOWED_REWARD_TYPES = %w[free_item vip_experience secret_menu].freeze

  # Default listing order: id matches creation order for serial PKs and keeps the
  # Pagy keyset cursor as a single integer (JSON round-trips exactly). Composite
  # cursors that include timestamps can misbehave across requests when ISO time
  # in the cursor does not match DB microsecond precision.
  DEFAULT_SORT = { id: :asc }.freeze

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

  def apply_sort(current_scope)
    field, direction = sort_parts

    if field.blank? || direction.nil?
      return current_scope.reorder(DEFAULT_SORT)
    end

    allowed_directions = self.class::SORTABLE[field]
    return current_scope unless allowed_directions&.include?(direction)

    current_scope.reorder(field => direction, id: direction)
  end

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
