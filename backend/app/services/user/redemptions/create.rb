module User::Redemptions
  class Create
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
      return success(existing, current_points_balance) if existing&.status == "completed"
      return failure("reward_unavailable", "Reward is not available for redemption") unless reward.is_available?

      ActiveRecord::Base.transaction do
        points_result = User::PointTransactions::Create.call(
          user: user,
          amount: -reward.points_cost,
          kind: "redeem",
          reason_code: "reward_redemption",
          idempotency_key: idempotency_key,
          reason: "Redeemed reward #{reward.id}",
          source: reward
        )

        return failure_from_points_result(points_result) unless points_result.success?

        redemption = existing || User::Redemption.new(user: user, idempotency_key: idempotency_key)
        redemption.update!(
          reward: reward,
          points_cost_snapshot: reward.points_cost,
          status: "completed"
        )

        success(redemption, points_result.transaction.running_balance)
      end
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
      user.point_transactions.order(created_at: :desc, id: :desc).pick(:running_balance) || 0
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
