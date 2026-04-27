class RedemptionHistoryQuery < BaseQuery
  FILTERABLE = {
    "status" => :filter_status
  }.freeze
  RANGE_FILTERS = {
    "points" => {
      field: "points_cost_snapshot",
      type: :integer,
      operators: %w[gte lte]
    },
    "created_at" => {
      field: "created_at",
      type: :datetime,
      operators: %w[gte lte]
    }
  }.freeze
  SORTABLE = {
    "created_at" => %i[asc desc],
    "points_cost_snapshot" => %i[asc desc]
  }.freeze

  private

  def filter_status(current_scope, value)
    status = value.to_s.strip
    return current_scope unless User::Redemption::STATUSES.include?(status)

    current_scope.where(status: status)
  end
end
