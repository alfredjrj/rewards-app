class RewardQuery < BaseQuery
  ALLOWED_REWARD_TYPES = %w[free_item vip_experience secret_menu].freeze

  FILTERABLE = {
    "query" => :filter_query,
    "reward_types" => :filter_reward_types,
    "points" => :filter_points
  }.freeze

  SORTABLE = {
    "title" => %i[asc desc],
    "points_cost" => %i[asc desc],
    "created_at" => %i[asc desc],
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

  def filter_points(current_scope, value)
    raw = normalize_hash_filter(value)
    min_points = normalize_positive_integer(raw["gte"])
    max_points = normalize_positive_integer(raw["lte"])
    return current_scope if min_points.nil? && max_points.nil?

    current_scope.by_points_cost(min: min_points, max: max_points)
  end

  def normalized_reward_types(value)
    clean_string_array(value).select { |type| ALLOWED_REWARD_TYPES.include?(type) }
  end

  def normalize_hash_filter(value)
    raw = if value.respond_to?(:to_unsafe_h)
      value.to_unsafe_h
    elsif value.is_a?(Hash)
      value
    else
      {}
    end

    raw.transform_keys(&:to_s)
  end

  def normalize_positive_integer(value)
    parsed = Integer(value, exception: false)
    parsed&.positive? ? parsed : nil
  end
end
