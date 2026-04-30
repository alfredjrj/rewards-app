class User::Redemptions::AuditJob
  include Sidekiq::Job
  sidekiq_options queue: :default, retry: 10, backtrace: 5

  # We intentionally rely on Redis durability (AOF mode) for queued payload retention.
  # When retries are exhausted, we log full payload details for compliance reconciliation.
  sidekiq_retries_exhausted do |msg, ex|
    Rails.logger.error(
      "[redemption.audit_job] retries_exhausted jid=#{msg['jid']} " \
      "error=#{ex.class}: #{ex.message} payload=#{msg['args']&.first.inspect}"
    )
  end

  def perform(payload)
    User::RedemptionAudit.create!(
      user_redemption_id: payload.fetch("user_redemption_id"),
      user_id: payload.fetch("user_id"),
      reward_id: payload.fetch("reward_id"),
      point_transaction_id: payload["point_transaction_id"],
      request_id: payload.fetch("request_id"),
      event_at: payload.fetch("event_at"),
      change_source_origin: payload.fetch("change_source_origin"),
      change_reason: payload.fetch("change_reason"),
      snapshot: payload.fetch("snapshot"),
      metadata: payload.fetch("metadata")
    )
  end
end
