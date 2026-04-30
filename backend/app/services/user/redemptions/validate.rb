module User::Redemptions
  # Shared precondition gate used before finalization writes.
  #
  # It validates:
  # - idempotent terminal replay behavior
  # - reward availability
  # - flow-specific reservation requirements
  #
  # Flows:
  # - :sync => no non-finalized existing redemption allowed
  # - :with_reservation => an existing redemption row is required
  class Validate
    FLOWS = %i[sync with_reservation].freeze

    Result = Struct.new(
      :halt?,
      :success?,
      :existing_redemption,
      :points_balance,
      :error_code,
      :error_message,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:, flow:)
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
      @flow = flow&.to_sym
    end

    def call
      if FLOWS.include?(flow)
        existing_redemption = user.redemptions.find_by(idempotency_key: idempotency_key)

        replay_result = result_for_finalized_redemption(existing_redemption)
        if replay_result
          replay_result
        else
          if reward.is_available?
            flow_precondition_result(existing_redemption)
          else
            reward_unavailable_result(existing_redemption)
          end
        end
      else
        raise ArgumentError, "Unknown validation flow: #{flow.inspect}"
      end
    end

    private

    attr_reader :user, :reward, :idempotency_key, :flow

    def result_for_finalized_redemption(existing_redemption)
      return nil unless existing_redemption&.finalized?
      return replay_completed_result(existing_redemption) if existing_redemption.completed?

      halted_failure(
        existing_redemption: existing_redemption,
        code: "redemption_finalized",
        message: "Redemption already finalized"
      )
    end

    def reward_unavailable_result(existing_redemption)
      halted_failure(
        existing_redemption: existing_redemption,
        code: "reward_unavailable",
        message: "Reward is not available for redemption"
      )
    end

    def flow_precondition_result(existing_redemption)
      if flow == :sync
        return proceed(existing_redemption) unless existing_redemption

        return halted_failure(
          existing_redemption: existing_redemption,
          code: "redemption_in_progress",
          message: "Redemption is currently processing"
        )
      end

      return proceed(existing_redemption) if existing_redemption

      halted_failure(
        existing_redemption: nil,
        code: "reservation_missing",
        message: "Redemption reservation was not found"
      )
    end

    def replay_completed_result(existing_redemption)
      Result.new(
        halt?: true,
        success?: true,
        existing_redemption: existing_redemption,
        points_balance: user.current_points_balance,
        error_code: nil,
        error_message: nil
      )
    end

    def proceed(existing_redemption)
      Result.new(
        halt?: false,
        success?: true,
        existing_redemption: existing_redemption,
        points_balance: nil,
        error_code: nil,
        error_message: nil
      )
    end

    def halted_failure(existing_redemption:, code:, message:)
      Result.new(
        halt?: true,
        success?: false,
        existing_redemption: existing_redemption,
        points_balance: nil,
        error_code: code,
        error_message: message
      )
    end
  end
end
