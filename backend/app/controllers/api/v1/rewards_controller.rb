class Api::V1::RewardsController < AuthenticationController
  DEFAULT_PER_PAGE = 6
  MAX_PER_PAGE = 50

  def index
    authorize :reward, :index?

    rewards = policy_scope(::Reward)
    query = params[:query].presence
    if query.present?
      # Use Postgres full-text search (title + description) for better relevance
      # and index-backed performance; LIKE scans are weaker and slower at scale.
      rewards = rewards.search_text(query)
    end

    pagy_request = Pagy::Request.new(
      request: request,
      limit: DEFAULT_PER_PAGE,
      max_limit: MAX_PER_PAGE,
      limit_key: "per_page"
    )
    # Page-based pagination fits this catalog UI ("page X of Y" + total count).
    # Cursor pagination is better for high-churn, infinite-scroll feeds.
    pagy_obj, paginated_rewards = Pagy::OffsetPaginator.paginate(rewards, request: pagy_request)

    render json: {
      data: paginated_rewards,
      meta: {
        page: pagy_obj.page,
        per_page: pagy_obj.limit,
        total_count: pagy_obj.count,
        total_pages: pagy_obj.pages
      }
    }
  end
end
