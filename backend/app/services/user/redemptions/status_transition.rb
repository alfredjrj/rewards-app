module User::Redemptions
  class StatusTransition
    TERMINAL_STATUSES = %w[completed failed cancelled].freeze
    STATUS_EVENTS = {
      "completed" => :complete,
      "failed" => :fail,
      "cancelled" => :cancel
    }.freeze

    def self.mark(user_id:, request_id:, status:, change_source_origin: "system", change_source_metadata: {})
      redemption = User::Redemption.find_by(user_id: user_id, idempotency_key: request_id)
      return false unless redemption
      event = STATUS_EVENTS[status.to_s]
      return false unless event
      return false unless redemption.public_send("may_#{event}?")

      redemption.public_send("#{event}!")
      User::Redemptions::Audit.record(
        redemption: redemption,
        change_reason: "updated",
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
      true
    end
  end
end
