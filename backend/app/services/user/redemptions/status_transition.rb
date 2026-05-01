module User::Redemptions
  class StatusTransition < ApplicationService
    include Auditable

    STATUS_EVENTS = {
      "completed" => :complete,
      "failed" => :fail,
      "cancelled" => :cancel
    }.freeze

    def self.mark(user_id:, request_id:, status:, change_source_origin: "system", change_source_metadata: {})
      new(
        user_id: user_id,
        request_id: request_id,
        status: status,
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      ).call
    end

    def initialize(user_id:, request_id:, status:, change_source_origin: "system", change_source_metadata: {})
      @user_id = user_id
      @request_id = request_id
      @status = status.to_s
      @audit_context = Auditable::AuditContext.new(origin: change_source_origin, metadata: change_source_metadata)
    end

    def call
      return false unless redemption
      return false unless event
      return false unless redemption.public_send("may_#{event}?")

      redemption.public_send("#{event}!")
      record_audit(redemption, change_reason: "updated")
      true
    end

    private

    attr_reader :user_id, :request_id, :status, :audit_context

    def redemption
      @redemption ||= User::Redemption.find_by(user_id: user_id, idempotency_key: request_id)
    end

    def event
      STATUS_EVENTS[status]
    end
  end
end
