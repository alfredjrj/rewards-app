module User::Redemptions
  class Create
    TERMINAL_STATUSES = %w[completed failed cancelled].freeze
    Result = Struct.new(:success?, :redemption, :points_balance, :error, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:)
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
    end

    def call
      existing = user.redemptions.find_by(idempotency_key: idempotency_key)
      if existing && TERMINAL_STATUSES.include?(existing.status)
        return success(existing, current_points_balance) if existing.status == "completed"

        return failure("redemption_finalized", "Redemption already finalized")
      end
      return failure("reward_unavailable", "Reward is not available for redemption") unless reward.is_available?

      points_result = nil
      redemption = existing || User::Redemption.new(user: user, idempotency_key: idempotency_key)

      ActiveRecord::Base.transaction do
        redemption.assign_attributes(
          reward: reward,
          points_cost_snapshot: reward.points_cost
        )
        redemption.save! if redemption.new_record?

        points_result = User::PointTransactions::Create.call(
          user: user,
          amount: -reward.points_cost,
          kind: "redeem",
          reason_code: "reward_redemption",
          idempotency_key: idempotency_key,
          reason: "Redeemed reward #{reward.id}",
          source: redemption
        )

        raise ActiveRecord::Rollback unless points_result.success?

        redemption.update!(
          reward: reward,
          points_cost_snapshot: reward.points_cost,
          status: "completed"
        )
      end

      return failure_from_points_result(points_result) unless points_result.success?

      success(redemption, points_result.transaction.running_balance)
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

    def current_points_balance
      user.current_points_balance
    end

    def success(redemption, points_balance)
      Result.new(success?: true, redemption: redemption, points_balance: points_balance, error: nil)
    end

    def failure_from_points_result(points_result)
      Result.new(success?: false, redemption: nil, points_balance: nil, error: points_result.error)
    end

    def failure(code, message, details: nil)
      Result.new(
        success?: false,
        redemption: nil,
        points_balance: nil,
        error: {
          code: code,
          message: message,
          details: details
        }.compact
      )
    end
  end
end
