class BaseQuery
  attr_reader :scope, :params

  # Subclasses define the query contract:
  # - FILTERABLE: filter key => method name
  # - SORTABLE: field => allowed directions
  #
  # Request DSL examples:
  # - /api/v1/rewards?filter[query]=coffee
  # - /api/v1/rewards?filter[reward_types][]=free_item&filter[points][lte]=300
  # - /api/v1/rewards?filter[points][gte]=100&filter[points][lte]=300
  # - /api/v1/rewards?sort=-points_cost&page=1&per_page=6
  #
  # Why this instead of Ransack:
  # - This API uses a strict, explicit whitelist contract for frontend clients.
  # - Query behavior is defined in plain Ruby per resource, which keeps
  #   parameter shape/versioning predictable and easy to review.
  # - Backend and frontend can work independently on top of a stable contract:
  #   backend controls allowed filters/sorts, while frontend composes only
  #   supported params without depending on Ransack internals.
  # - We avoid exposing a broad query DSL surface that frontend consumers do
  #   not need for this product.
  FILTERABLE = {}.freeze
  SORTABLE = {}.freeze

  def initialize(scope, params)
    @scope = scope
    @params = params
  end

  def call
    filtered = apply_filters(scope)
    apply_sort(filtered)
  end

  private

  def apply_filters(current_scope)
    filters.reduce(current_scope) do |memo, (key, value)|
      next memo if value.blank?

      filter_method = self.class::FILTERABLE[key.to_s]
      filter_method ? send(filter_method, memo, value) : memo
    end
  end

  def apply_sort(current_scope)
    field, direction = sort_parts
    return current_scope if field.blank? || direction.nil?

    allowed_directions = self.class::SORTABLE[field]
    return current_scope unless allowed_directions&.include?(direction)

    current_scope.reorder(field => direction)
  end

  def filters
    raw = params[:filter]
    return {} if raw.blank?
    return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
    return raw if raw.is_a?(Hash)

    {}
  end

  def sort_parts
    sort_value = params[:sort].to_s.strip
    return [nil, nil] if sort_value.blank?

    direction = sort_value.start_with?("-") ? :desc : :asc
    field = sort_value.delete_prefix("-")
    return [nil, nil] if field.blank?

    [field, direction]
  end

  def clean_string_array(value)
    Array(value).map { |item| item.to_s.strip }.reject(&:blank?)
  end
end
