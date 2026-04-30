module User::Redemptions
  # Appends a `User::RedemptionAudit` row: one JSON snapshot of the redemption after each change.
  #
  # Money and balances live in `User::PointTransaction` (the ledger). Audit rows are only an operational
  # history (who changed what, when), not the source of truth for balances.
  #
  # Provenance is explicit at each call site via `change_source_origin` / `change_source_metadata`.
  # Callers should pass values from the current execution context (api request, background job, seeds, etc).
  class Audit
    # Queue audit persistence so redemptions can still process if audit insertion fails transiently.
    # If the job exhausts retries, we log payload details so compliance reconciliation can run later.
    def self.record(
      redemption:,
      change_reason:,
      change_source_origin: "system",
      change_source_metadata: {},
      point_transaction: nil
    )
      payload = build_payload(
        redemption: redemption,
        change_reason: change_reason,
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata,
        point_transaction: point_transaction
      )
      # Enqueue only after DB commit so rolled-back transactions do not emit phantom audit jobs.
      ActiveRecord.after_all_transactions_commit do
        begin
          enqueue_payload(payload)
        rescue StandardError => e
          Rails.logger.error(
            "[redemption.audit] enqueue_failed redemption_id=#{redemption.id} " \
            "change_reason=#{change_reason} error=#{e.class}: #{e.message}"
          )
        end
      end
      payload
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

    def self.build_payload(redemption:, change_reason:, change_source_origin:, change_source_metadata:, point_transaction:)
      {
        user_redemption_id: redemption.id,
        user_id: redemption.user_id,
        reward_id: redemption.reward_id,
        point_transaction_id: point_transaction&.id,
        request_id: redemption.idempotency_key,
        event_at: Time.current.iso8601(6),
        change_source_origin: change_source_origin.to_s,
        change_reason: change_reason.to_s,
        snapshot: snapshot_for(redemption),
        metadata: change_source_metadata.deep_stringify_keys
      }
    end

    def self.enqueue_payload(payload)
      User::Redemptions::AuditJob.perform_async(payload.deep_stringify_keys)
    end
    private_class_method :build_payload, :enqueue_payload
  end
end
