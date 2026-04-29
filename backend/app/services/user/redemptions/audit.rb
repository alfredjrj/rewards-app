module User::Redemptions
  # Audit contract:
  # - User::PointTransaction is the financial source of truth for balances/reconciliation.
  # - User::RedemptionAudit stores per-change snapshots of User::Redemption for history/debugging.
  # - Audits keep relational references (redemption/reward/user/optional point transaction).
  class Audit
    def self.record(
      redemption:,
      change_reason:,
      change_source:,
      metadata: {},
      point_transaction: nil
    )
      User::RedemptionAudit.create!(
        redemption: redemption,
        user: redemption.user,
        reward: redemption.reward,
        point_transaction: point_transaction,
        request_id: redemption.idempotency_key,
        change_source: change_source,
        change_reason: change_reason,
        snapshot: snapshot_for(redemption),
        metadata: metadata
      )
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
  end
end
