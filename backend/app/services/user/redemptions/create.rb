module User::Redemptions
  # Final redemption writer used by both entry paths.
  #
  # Modes:
  # - :none => sync/internal path; writes a completed redemption inline
  # - :required => async finalization path; requires an existing processing reservation
  #
  # Responsibilities:
  # - run shared preconditions via `User::Redemptions::Validate`
  # - write the points debit and redemption status transition in one transaction
  # - enqueue async audit persistence for each state change
  class Create < ApplicationService
    include Auditable
    RESERVATION_MODES = %i[none required].freeze

    def initialize(user:, reward:, idempotency_key:, reservation_mode: :none, change_source_origin: "system", change_source_metadata: {})
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
      @audit_context = Auditable::AuditContext.new(origin: change_source_origin, metadata: change_source_metadata)
      @reservation_mode = reservation_mode.to_sym
      raise ArgumentError, "Unknown reservation_mode: #{@reservation_mode.inspect}" unless RESERVATION_MODES.include?(@reservation_mode)
    end

    def call
      validation = User::Redemptions::Validate.call(
        user: user,
        reward: reward,
        idempotency_key: idempotency_key,
        flow: validation_flow
      )
      return idempotent_replay_result(validation) if validation.idempotent_replay?
      return halted_validation_failure_result(validation) if validation.halt?

      if reservation_mode == :required
        finalize_redemption(source_redemption: validation.redemption) do |point_transaction|
          complete_existing!(validation.redemption, point_transaction)
        end
      else
        finalize_redemption(source_redemption: nil) do |point_transaction|
          create_completed!(point_transaction)
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(e.full_message)
      ServiceResult.failure(
        **RedemptionErrors::VALIDATION_ERROR.merge(message: validation_message_for(e.record)),
        details: e.record.errors.to_hash(true),
        redemption: nil,
        points_balance: nil,
        point_transaction: nil
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key, :audit_context, :reservation_mode

    def validation_flow
      reservation_mode == :required ? :with_reservation : :sync
    end

    def idempotent_replay_result(validation)
      ServiceResult.success(
        redemption: validation.existing_redemption,
        points_balance: validation.points_balance
      )
    end

    def halted_validation_failure_result(validation)
      ServiceResult.failure(
        **validation.error,
        halt: validation.halt?,
        redemption: nil,
        points_balance: nil,
        point_transaction: nil
      )
    end

    def finalize_redemption(source_redemption:)
      points_result = nil
      redemption = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        points_result = debit_points!(source_redemption)
        raise ActiveRecord::Rollback unless points_result.success?
        redemption = yield(points_result.point_transaction)
      end

      return ServiceResult.failure(
        **points_result.error,
        redemption: nil,
        points_balance: nil,
        point_transaction: nil
      ) unless points_result.success?

      ServiceResult.success(
        redemption: redemption,
        points_balance: points_result.point_transaction.running_balance,
        point_transaction: points_result.point_transaction
      )
    end

    def debit_points!(existing_redemption)
      points_cost_snapshot = existing_redemption&.points_cost_snapshot || reward.points_cost
      User::PointTransactions::Create.call(
        user: user,
        amount: -points_cost_snapshot,
        kind: "redeem",
        reason_code: "reward_redemption",
        idempotency_key: idempotency_key,
        reason: "Redeemed reward #{reward.id}",
        source: existing_redemption
      )
    end

    def create_completed!(point_transaction)
      redemption = user.redemptions.create!(
        reward: reward,
        points_cost_snapshot: reward.points_cost,
        status: "completed",
        idempotency_key: idempotency_key
      )
      record_audit(redemption, change_reason: "created", point_transaction: point_transaction)
      redemption
    end

    def complete_existing!(redemption, point_transaction)
      transitioned = redemption.complete!
      raise ActiveRecord::RecordInvalid.new(redemption) unless transitioned

      record_audit(redemption, change_reason: "updated", point_transaction: point_transaction)
      redemption
    end

    def validation_message_for(record)
      message = record.errors.full_messages.to_sentence
      message.presence || RedemptionErrors::VALIDATION_ERROR[:message]
    end
  end
end
