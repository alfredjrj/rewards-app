class Api::V1::RewardsController < AuthenticationController
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 50

  def index
    authorize :reward, :index?

    rewards = RewardQuery.new(policy_scope(::Reward), params).call

    pagy_request = Pagy::Request.new(
      request: request,
      limit: DEFAULT_PER_PAGE,
      max_limit: MAX_PER_PAGE,
      limit_key: "per_page"
    )
    # Page-based pagination fits this catalog UI ("page X of Y" + total count).
    # Cursor pagination is better for high-churn, infinite-scroll feeds.
    pagy_obj, paginated_rewards = Pagy::OffsetPaginator.paginate(rewards, request: pagy_request)

    render json: ::Api::V1::RewardSerializer::Collection
      .call(rewards: paginated_rewards)
      .merge(meta: ::Api::V1::PaginationMetaSerializer.call(pagy: pagy_obj))
  end
end
