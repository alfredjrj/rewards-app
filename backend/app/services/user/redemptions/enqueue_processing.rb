module User::Redemptions
  class EnqueueProcessing
    Result = Struct.new(:success?, :error, :redemption, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:)
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
    end

    def call
      user.with_lock do
        existing = user.redemptions.find_by(idempotency_key: idempotency_key)
        return Result.new(success?: true, error: nil, redemption: existing) if existing

        unless sufficient_points_available?
          return Result.new(
            success?: false,
            error: {
              code: "insufficient_balance",
              message: "Insufficient points balance"
            },
            redemption: nil
          )
        end

        redemption = user.redemptions.create!(
          reward: reward,
          points_cost_snapshot: reward.points_cost,
          status: "processing",
          idempotency_key: idempotency_key
        )
        @created_redemption = redemption
      end

      # Demo / interview only: enqueue processing later so "processing" state is visible in UI;
      # not a production latency strategy (use perform_async there).
      User::Redemptions::ProcessJob.perform_in(2.second, user.id, reward.id, idempotency_key)
      Result.new(success?: true, error: nil, redemption: @created_redemption)
    rescue StandardError => e
      Rails.logger.warn(e.full_message)
      @created_redemption&.update!(status: "failed")
      Result.new(
        success?: false,
        error: {
          code: "enqueue_unavailable",
          message: "Redemption queue is temporarily unavailable. Please try again."
        },
        redemption: @created_redemption
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key

    def sufficient_points_available?
      points = User::Points::AvailableBalance.call(user: user)
      points[:points_available] >= reward.points_cost
    end
  end
end
