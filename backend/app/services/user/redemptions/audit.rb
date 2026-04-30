module User::Redemptions
  # Appends a `User::RedemptionAudit` row: one JSON snapshot of the redemption after each change.
  #
  # Money and balances live in `User::PointTransaction` (the ledger). Audit rows are only an operational
  # history (who changed what, when), not the source of truth for balances.
  #
  # Provenance: call `redemption.assign_change_source_origin` before the save, and/or pass `change_source_origin` /
  # `change_source_metadata` into `record`. If you skip both, `change_source_origin` falls back to `"system"`
  # (persisted as `user_redemption_audits.change_source_origin`).
  class Audit
    # Persists one audit row. Provenance: optional kwargs and/or `assign_change_source_origin`; otherwise `"system"`.
    def self.record(
      redemption:,
      change_reason:,
      change_source_origin: nil,
      change_source_metadata: {},
      point_transaction: nil
    )
      resolved = resolve_change_source_origin(change_source_origin: change_source_origin, redemption: redemption)
      merged_metadata = merge_change_source_metadata(
        redemption: redemption,
        change_source_metadata: change_source_metadata
      )

      audit = User::RedemptionAudit.new(
        redemption: redemption,
        user: redemption.user,
        reward: redemption.reward,
        point_transaction: point_transaction,
        request_id: redemption.idempotency_key,
        change_source_origin: resolved,
        change_reason: change_reason.to_s,
        snapshot: snapshot_for(redemption),
        metadata: merged_metadata
      )

      begin
        audit.save!
      rescue ActiveRecord::RecordInvalid
        Rails.logger.error(
          "[redemption.audit] persist_failed redemption_id=#{redemption.id} " \
          "change_reason=#{change_reason} errors=#{audit.errors.full_messages.join(', ')}"
        )
      end
      audit
    end

    def self.snapshot_for(redemption)
      {
        id: redemption.id,
        user_id: redemption.user_id,
        reward_id: redemption.reward_id,
        status: redemption.status,
        points_cost_snapshot: redemption.points_cost_snapshot,
        idempotency_key: redemption.idempotency_key
      }
    end

    # Pick first non-blank origin: explicit arg -> redemption value -> "system".
    def self.resolve_change_source_origin(change_source_origin:, redemption:)
      (
        change_source_origin.presence ||
        redemption.try(:change_source_origin).presence ||
        "system"
      ).to_s
    end

    # Merge metadata in this order:
    # 1) base metadata already attached to the redemption
    # 2) metadata passed into this method (overrides duplicate keys)
    def self.merge_change_source_metadata(redemption:, change_source_metadata:)
      base_metadata = metadata_from_redemption(redemption)
      call_metadata = change_source_metadata.deep_stringify_keys
      base_metadata.merge(call_metadata)
    end

    def self.metadata_from_redemption(redemption)
      return {} unless redemption.respond_to?(:change_source_metadata)

      redemption.change_source_metadata || {}
    end

    private_class_method :resolve_change_source_origin,
                         :merge_change_source_metadata,
                         :metadata_from_redemption
  end
end
