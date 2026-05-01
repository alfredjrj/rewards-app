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
  class Validate < ApplicationService
    FLOWS = %i[sync with_reservation].freeze

    def initialize(user:, reward:, idempotency_key:, flow:)
      @flow = flow&.to_sym
      raise ArgumentError, "Unknown validation flow: #{flow.inspect}" unless FLOWS.include?(@flow)

      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
    end

    def call
      return replay_completed_result if existing_redemption&.completed?
      return halted_failure(existing_redemption: existing_redemption, **RedemptionErrors::REDEMPTION_FINALIZED) if existing_redemption&.finalized?
      return halted_failure(existing_redemption: existing_redemption, **RedemptionErrors::REWARD_UNAVAILABLE) unless reward.is_available?

      flow_precondition_result
    end

    private

    attr_reader :user, :reward, :idempotency_key, :flow

    def existing_redemption
      @existing_redemption ||= user.redemptions.find_by(idempotency_key: idempotency_key)
    end

    def flow_precondition_result
      case flow
      when :sync
        existing_redemption ? halted_failure(existing_redemption: existing_redemption, **RedemptionErrors::REDEMPTION_IN_PROGRESS) : proceed
      when :with_reservation
        existing_redemption ? proceed : halted_failure(existing_redemption: nil, **RedemptionErrors::RESERVATION_MISSING)
      end
    end

    def replay_completed_result
      ServiceResult.success(
        halt: true,
        redemption: existing_redemption,
        existing_redemption: existing_redemption,
        points_balance: user.current_points_balance,
        error_code: nil,
        error_message: nil
      )
    end

    def proceed
      ServiceResult.success(
        halt: false,
        redemption: existing_redemption,
        existing_redemption: existing_redemption,
        error_code: nil,
        error_message: nil
      )
    end

    def halted_failure(existing_redemption:, code:, message:)
      ServiceResult.failure(
        halt: true,
        redemption: existing_redemption,
        existing_redemption: existing_redemption,
        error_code: code,
        error_message: message,
        code: code,
        message: message
      )
    end
  end
end
