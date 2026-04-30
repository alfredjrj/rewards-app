module User::Redemptions
  # External-provider entrypoint used by the controller.
  #
  # It reserves a processing redemption (credit hold semantics) and enqueues async
  # finalization exactly once per idempotency key.
  class PlaceCreditHoldAndReserve
    Result = Struct.new(:success?, :error, :redemption, :reserved_new?, keyword_init: true)

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
      reserve_result = reserve_pending_redemption
      return reserve_result unless reserve_result.success?

      @redemption = reserve_result.redemption
      if reserve_result.reserved_new?
        enqueue_async_fulfillment!
        success(@redemption, reserved_new: true)
      else
        success(@redemption, reserved_new: false)
      end
    rescue StandardError => e
      Rails.logger.warn(e.full_message)
      mark_failed(
        @redemption,
        metadata: change_source_metadata.merge("failure" => "enqueue_unavailable")
      )
      failure(
        code: "enqueue_unavailable",
        message: "Redemption queue is temporarily unavailable. Please try again.",
        redemption: @redemption
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key, :change_source_origin, :change_source_metadata

    def reserve_pending_redemption
      user.with_lock do
        existing_redemption = user.redemptions.find_by(idempotency_key: idempotency_key)
        return success(existing_redemption, reserved_new: false) if existing_redemption
        return insufficient_balance_failure unless sufficient_points_available?

        success(create_processing_redemption, reserved_new: true)
      end
    end

    def enqueue_async_fulfillment!
      # Small delay lets the processing hold + audit commit before workers read state,
      # reducing racey "not found/missing reservation" behavior under load.
      User::Redemptions::ProcessJob.perform_in(2.second, user.id, reward.id, idempotency_key)
    end

    def create_processing_redemption
      redemption = user.redemptions.new(
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "processing",
        idempotency_key: idempotency_key
      )
      redemption.save!
      User::Redemptions::Audit.record_async(
        redemption: redemption,
        change_reason: "created",
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
      redemption
    end

    def sufficient_points_available?
      points = User::Points::AvailableBalance.call(user: user)
      points[:points_available] >= reward.points_cost
    end

    def mark_failed(redemption, metadata:)
      return unless redemption

      transitioned = redemption.fail!
      if transitioned
        User::Redemptions::Audit.record_async(
          redemption: redemption,
          change_reason: "updated",
          change_source_origin: change_source_origin,
          change_source_metadata: metadata
        )
      else
        Rails.logger.error(
          "[redemption.place_credit_hold_and_reserve] transition_failed redemption_id=#{redemption.id} " \
          "from=#{redemption.status} to=failed"
        )
      end
    end

    def success(redemption, reserved_new:)
      Result.new(success?: true, error: nil, redemption: redemption, reserved_new?: reserved_new)
    end

    def failure(code:, message:, details: nil, redemption: nil)
      Result.new(
        success?: false,
        error: {
          code: code,
          message: message,
          details: details
        }.compact,
        redemption: redemption,
        reserved_new?: false
      )
    end

    def insufficient_balance_failure
      failure(
        code: "insufficient_balance",
        message: "Insufficient points balance"
      )
    end
  end
end
