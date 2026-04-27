class Api::V1::RewardCursorMetaSerializer
  def self.call(pagy:)
    token = pagy.next

    {
      per_page: pagy.limit,
      next_cursor: token,
      has_next: token.present?
    }
  end
end
