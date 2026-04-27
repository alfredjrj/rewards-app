class Api::V1::RewardsController < AuthenticationController
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE = 50

  def index
    authorize :reward, :index?

    rewards = RewardQuery.new(policy_scope(::Reward), params).call
    rewards = rewards.unscope(:select) if rewards.select_values.present?

    pagy_opts = {
      limit: DEFAULT_PER_PAGE,
      max_limit: MAX_PER_PAGE,
      limit_key: "per_page",
      page_key: "cursor",
      tuple_comparison: true,
      request: request
    }
    pagy_opts[:request] = Pagy::Request.new(pagy_opts)

    # Keyset (cursor) pagination via Pagy avoids large OFFSET scans and gives
    # consistent pages when rewards are added or removed between requests—common
    # for a catalog that changes while users browse.
    pagy_obj, paginated_rewards = Pagy::KeysetPaginator.paginate(rewards, pagy_opts)

    render json: ::Api::V1::RewardSerializer::Collection
      .call(rewards: paginated_rewards)
      .merge(meta: ::Api::V1::RewardCursorMetaSerializer.call(pagy: pagy_obj))
  end
end
