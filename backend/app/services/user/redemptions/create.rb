module User::Redemptions
  # Completes a reserved redemption by debiting points and marking it completed.
  # Supports idempotent replay and terminal-state short-circuiting.
  class Create
    TERMINAL_STATUSES = %w[completed failed cancelled].freeze
    Result = Struct.new(:success?, :redemption, :points_balance, :point_transaction, :error, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:)
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
    end

    def call
      existing_redemption = find_existing_redemption
      replay_result = terminal_replay_result_for(existing_redemption)
      return replay_result if replay_result
      return reward_unavailable_result unless reward.is_available?

      redemption = existing_redemption || build_redemption
      points_result = complete_redemption!(redemption)
      return failure_from_points_result(points_result) unless points_result.success?

      success(
        redemption,
        points_result.transaction.running_balance,
        points_result.transaction
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(e.full_message)
      failure(
        "validation_error",
        "Redemption is invalid",
        details: e.record.errors.to_hash(true)
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key

    def find_existing_redemption
      user.redemptions.find_by(idempotency_key: idempotency_key)
    end

    def terminal_replay_result_for(existing_redemption)
      return nil unless existing_redemption
      return nil unless TERMINAL_STATUSES.include?(existing_redemption.status)

      return success(existing_redemption, current_points_balance) if existing_redemption.status == "completed"

      failure("redemption_finalized", "Redemption already finalized")
    end

    def reward_unavailable_result
      failure("reward_unavailable", "Reward is not available for redemption")
    end

    def build_redemption
      User::Redemption.new(user: user, idempotency_key: idempotency_key)
    end

    def complete_redemption!(redemption)
      points_result = nil

      ActiveRecord::Base.transaction do
        persist_redemption_snapshot!(redemption)
        points_result = create_points_debit_for(redemption)
        raise ActiveRecord::Rollback unless points_result.success?

        mark_redemption_completed!(redemption)
      end

      points_result
    end

    def persist_redemption_snapshot!(redemption)
      redemption.assign_attributes(
        reward: reward,
        points_cost_snapshot: reward.points_cost
      )
      redemption.save! if redemption.new_record?
    end

    def create_points_debit_for(redemption)
      User::PointTransactions::Create.call(
        user: user,
        amount: -reward.points_cost,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: idempotency_key,
        reason: "Redeemed reward #{reward.id}",
        source: redemption
      )
    end

    def mark_redemption_completed!(redemption)
      redemption.update!(
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "completed"
      )
    end

    def current_points_balance
      user.current_points_balance
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
        error: {
          code: code,
          message: message,
          details: details
        }.compact
      )
    end
  end
end
