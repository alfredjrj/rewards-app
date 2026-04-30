module User::Redemptions
  class StatusTransition
    TERMINAL_STATUSES = %w[completed failed cancelled].freeze

    def self.mark(user_id:, request_id:, status:, change_source_origin: "system", change_source_metadata: {})
      redemption = User::Redemption.find_by(user_id: user_id, idempotency_key: request_id)
      return false unless redemption
      return false if TERMINAL_STATUSES.include?(redemption.status)
      return false if redemption.status == status

      redemption.assign_change_source_origin(
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
      redemption.update!(status: status)
      true
    end
  end
end
