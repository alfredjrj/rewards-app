module User::Redemptions
  # Shared orchestration for finalizing a redemption (sync or async).
  #
  # Flow (template method):
  #   1) Look up any existing redemption by idempotency_key
  #   2) Replay terminal results idempotently (completed/failed/cancelled)
  #   3) Reject if reward is no longer available
  #   4) Run subclass guard (`pre_finalize_guard`) for state-specific preconditions
  #   5) Run subclass `finalize!` to debit points + persist redemption + audit
  #
  # Subclasses implement:
  #   - `pre_finalize_guard(existing_redemption)` -> nil to proceed, Result to short-circuit
  #   - `finalize!(existing_redemption)` -> Result
  class CreateBase
    Result = Struct.new(
      :success?,
      :redemption,
      :points_balance,
      :point_transaction,
      :error,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:, change_source_origin: "system", change_source_metadata: {})
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
      @change_source_origin = change_source_origin
      @change_source_metadata = change_source_metadata
    end

    def call
      existing_redemption = find_existing_redemption

      replay = terminal_replay_result_for(existing_redemption)
      return replay if replay
      return reward_unavailable_result unless reward.is_available?

      guard_result = pre_finalize_guard(existing_redemption)
      return guard_result if guard_result

      finalize!(existing_redemption)
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(e.full_message)
      failure(
        "validation_error",
        "Redemption is invalid",
        details: e.record.errors.to_hash(true)
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key, :change_source_origin, :change_source_metadata

    # Subclass hook: return a Result to short-circuit, or nil to continue.
    def pre_finalize_guard(_existing_redemption)
      nil
    end

    # Subclass hook: must return a Result.
    def finalize!(_existing_redemption)
      raise NotImplementedError, "#{self.class} must implement #finalize!"
    end

    def find_existing_redemption
      user.redemptions.find_by(idempotency_key: idempotency_key)
    end

    def terminal_replay_result_for(existing_redemption)
      return nil unless existing_redemption
      return nil unless User::Redemption::TERMINAL_STATUSES.include?(existing_redemption.status)

      return success(existing_redemption, user.current_points_balance) if existing_redemption.status == "completed"

      failure("redemption_finalized", "Redemption already finalized")
    end

    def reward_unavailable_result
      failure("reward_unavailable", "Reward is not available for redemption")
    end

    def create_points_debit_for(points_cost_snapshot:, source:)
      User::PointTransactions::Create.call(
        user: user,
        amount: -points_cost_snapshot,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: idempotency_key,
        reason: "Redeemed reward #{reward.id}",
        source: source
      )
    end

    def record_audit_for(redemption, change_reason:, point_transaction: nil)
      User::Redemptions::Audit.record_async(
        redemption: redemption,
        change_reason: change_reason,
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata,
        point_transaction: point_transaction
      )
    end

    def success(redemption, points_balance, point_transaction = nil)
      Result.new(
        success?: true,
        redemption: redemption,
        points_balance: points_balance,
        point_transaction: point_transaction,
        error: nil
      )
    end

    def failure_from_points_result(points_result)
      Result.new(
        success?: false,
        redemption: nil,
        points_balance: nil,
        point_transaction: nil,
        error: points_result.error
      )
    end

    def failure(code, message, details: nil)
      Result.new(
        success?: false,
        redemption: nil,
        points_balance: nil,
        point_transaction: nil,
        error: { code: code, message: message, details: details }.compact
      )
    end
  end
end
