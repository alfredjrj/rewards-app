module User::Redemptions
  # Builds and enqueues redemption audit events for async persistence.
  #
  # Important: this service does NOT insert `User::RedemptionAudit` rows inline.
  # It only enqueues `AuditJob` after commit, so rolled-back writes do not emit audit events.
  #
  # Money and balances remain sourced from `User::PointTransaction` (ledger). Audit rows are
  # operational history ("who changed what, when"), not accounting source of truth.
  class AuditAsync
    def self.call(...)
      new(...).call
    end

    def self.snapshot_for(redemption)
      redemption.as_json(
        only: %i[
          id
          user_id
          reward_id
          status
          points_cost_snapshot
          idempotency_key
        ]
      )
    end

    def initialize(
      redemption:,
      change_reason:,
      change_source_origin: "system",
      change_source_metadata: {},
      point_transaction: nil
    )
      @redemption = redemption
      @change_reason = change_reason
      @change_source_origin = change_source_origin
      @change_source_metadata = change_source_metadata
      @point_transaction = point_transaction
    end

    # Returns the payload that was queued (or attempted to be queued).
    def call
      payload = build_payload
      enqueue_after_commit(payload)
      payload
    end

    private

    attr_reader :redemption, :change_reason, :change_source_origin, :change_source_metadata, :point_transaction

    def build_payload
      {
        user_redemption_id: redemption.id,
        user_id: redemption.user_id,
        reward_id: redemption.reward_id,
        point_transaction_id: point_transaction&.id,
        request_id: redemption.idempotency_key,
        event_at: Time.current.iso8601(6),
        change_source_origin: change_source_origin.to_s,
        change_reason: change_reason.to_s,
        snapshot: self.class.snapshot_for(redemption),
        metadata: change_source_metadata.deep_stringify_keys
      }
    end

    def enqueue_after_commit(payload)
      ActiveRecord.after_all_transactions_commit do
        safely_enqueue_payload(payload)
      end
    end

    def safely_enqueue_payload(payload)
      enqueue_payload(payload)
    rescue StandardError => e
      Rails.logger.error(
        "[redemption.audit] enqueue_failed redemption_id=#{redemption.id} " \
        "change_reason=#{change_reason} error=#{e.class}: #{e.message}"
      )
    end

    def enqueue_payload(payload)
      User::Redemptions::AuditJob.perform_async(payload.deep_stringify_keys)
    end
  end
end
