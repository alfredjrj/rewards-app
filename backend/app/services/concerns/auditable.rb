module Auditable
  extend ActiveSupport::Concern

  class AuditContext
    attr_reader :origin, :metadata

    def initialize(origin:, metadata: {})
      @origin = origin.to_s
      @metadata = (metadata || {}).deep_stringify_keys
    end

    def with(extra_metadata = {})
      self.class.new(origin: origin, metadata: metadata.merge((extra_metadata || {}).deep_stringify_keys))
    end
  end

  private

  def record_audit(redemption, change_reason:, point_transaction: nil, extra_metadata: {})
    context = audit_context.with(extra_metadata)
    User::Redemptions::AuditAsync.call(
      redemption: redemption,
      change_reason: change_reason,
      change_source_origin: context.origin,
      change_source_metadata: context.metadata,
      point_transaction: point_transaction
    )
  end
end
