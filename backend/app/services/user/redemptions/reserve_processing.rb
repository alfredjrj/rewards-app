module User::Redemptions
  # Reserves a processing redemption row (idempotently) and enqueues async completion.
  class ReserveProcessing
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
      reserve_result = reserve_processing_redemption
      return reserve_result if reserve_result.is_a?(Result)

      @created_redemption = reserve_result

      # Demo / interview only: enqueue processing later so "processing" state is visible in UI;
      # not a production latency strategy (use perform_async there).
      User::Redemptions::ProcessJob.perform_in(2.second, user.id, reward.id, idempotency_key)
      success(@created_redemption)
    rescue StandardError => e
      Rails.logger.warn(e.full_message)
      @created_redemption&.update!(status: "failed")
      enqueue_unavailable_failure(@created_redemption)
    end

    private

    attr_reader :user, :reward, :idempotency_key

    def reserve_processing_redemption
      user.with_lock do
        existing_redemption = find_existing_redemption
        return success(existing_redemption) if existing_redemption
        return insufficient_balance_failure unless sufficient_points_available?

        create_processing_redemption
      end
    end

    def find_existing_redemption
      user.redemptions.find_by(idempotency_key: idempotency_key)
    end

    def create_processing_redemption
      user.redemptions.create!(
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
    end

    def sufficient_points_available?
      points = User::Points::AvailableBalance.call(user: user)
      points[:points_available] >= reward.points_cost
    end

    def success(redemption)
      Result.new(success?: true, error: nil, redemption: redemption)
    end

    def insufficient_balance_failure
      Result.new(
        success?: false,
        error: {
          code: "insufficient_balance",
          message: "Insufficient points balance"
        },
        redemption: nil
      )
    end

    def enqueue_unavailable_failure(redemption)
      Result.new(
        success?: false,
        error: {
          code: "enqueue_unavailable",
          message: "Redemption queue is temporarily unavailable. Please try again."
        },
        redemption: redemption
      )
    end
  end
end
