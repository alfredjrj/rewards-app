module User::Redemptions
  # External-provider entrypoint used by the controller.
  #
  # It reserves a processing redemption (credit hold semantics) and enqueues async
  # finalization exactly once per idempotency key.
  class PlaceCreditHoldAndReserve < ApplicationService
    include Auditable
    ENQUEUE_TRANSIENT_EXCEPTIONS = [
      (Redis::BaseConnectionError if defined?(Redis::BaseConnectionError)),
      (Sidekiq::Shutdown if defined?(Sidekiq::Shutdown))
    ].compact.freeze


    def initialize(user:, reward:, idempotency_key:, change_source_origin: "system", change_source_metadata: {})
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
      @audit_context = Auditable::AuditContext.new(origin: change_source_origin, metadata: change_source_metadata)
    end

    def call
      reserve_result = reserve_pending_redemption
      if reserve_result.success?
        @redemption = reserve_result.redemption
        if reserve_result.reserved_new?
          enqueue_async_fulfillment!
          success(@redemption, reserved_new: true)
        else
          success(@redemption, reserved_new: false)
        end
      else
        reserve_result
      end
    rescue StandardError => e
      raise unless enqueue_transient_error?(e)

      Rails.logger.warn(e.full_message)
      mark_failed(
        @redemption,
        metadata: audit_context.metadata.merge("failure" => RedemptionErrors::ENQUEUE_UNAVAILABLE[:code])
      )
      failure(
        **RedemptionErrors::ENQUEUE_UNAVAILABLE,
        redemption: @redemption
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key, :audit_context

    def reserve_pending_redemption
      user.with_lock do
        existing_redemption = user.redemptions.find_by(idempotency_key: idempotency_key)
        if existing_redemption
          success(existing_redemption, reserved_new: false)
        else
          if sufficient_points_available?
            success(create_processing_redemption, reserved_new: true)
          else
            insufficient_balance_failure
          end
        end
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
      record_audit(redemption, change_reason: "created")
      redemption
    end

    def sufficient_points_available?
      points = User::Points::AvailableBalance.call(user: user)
      points[:points_available] >= reward.points_cost
    end

    def mark_failed(redemption, metadata:)
      if redemption
        transitioned = redemption.fail!
        if transitioned
          record_audit(redemption, change_reason: "updated", extra_metadata: metadata)
        else
          Rails.logger.error(
            "[redemption.place_credit_hold_and_reserve] transition_failed redemption_id=#{redemption.id} " \
            "from=#{redemption.status} to=failed"
          )
        end
      else
        nil
      end
    end

    def success(redemption, reserved_new:)
      ServiceResult.success(redemption: redemption, reserved_new: reserved_new, reserved_new?: reserved_new)
    end

    def failure(code:, message:, details: nil, redemption: nil)
      ServiceResult.failure(
        code: code,
        message: message,
        details: details,
        redemption: redemption,
        reserved_new: false,
        reserved_new?: false
      )
    end

    def insufficient_balance_failure
      failure(**RedemptionErrors::INSUFFICIENT_BALANCE)
    end

    def enqueue_transient_error?(exception)
      ENQUEUE_TRANSIENT_EXCEPTIONS.any? { |klass| exception.is_a?(klass) }
    end
  end
end
