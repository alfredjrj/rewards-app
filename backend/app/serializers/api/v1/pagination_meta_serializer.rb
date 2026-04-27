class Api::V1::PaginationMetaSerializer
  def self.call(pagy:)
    {
      page: pagy.page,
      per_page: pagy.limit,
      total_count: pagy.count,
      total_pages: pagy.pages
    }
  end
end
