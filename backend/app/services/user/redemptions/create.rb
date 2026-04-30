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
  class Create
    RESERVATION_MODES = %i[none required].freeze
    Result = Struct.new(
      :success?,
      :redemption,
      :points_balance,
      :point_transaction,
      :error,
      keyword_init: true
    )

    def self.call(...)
      new(...).call
    end

    def initialize(user:, reward:, idempotency_key:, reservation_mode: :none, change_source_origin: "system", change_source_metadata: {})
      @user = user
      @reward = reward
      @idempotency_key = idempotency_key
      @change_source_origin = change_source_origin
      @change_source_metadata = change_source_metadata
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
      if validation.halt?
        result_from_validation(validation)
      else
        return finalize_with_reservation!(validation.existing_redemption) if reservation_mode == :required

        finalize_without_reservation!
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.warn(e.full_message)
      build_result(
        success: false,
        error: {
          code: "validation_error",
          message: "Redemption is invalid",
          details: e.record.errors.to_hash(true)
        }.compact
      )
    end

    private

    attr_reader :user, :reward, :idempotency_key, :change_source_origin, :change_source_metadata, :reservation_mode

    def validation_flow
      reservation_mode == :required ? :with_reservation : :sync
    end

    def result_from_validation(validation)
      if validation.success?
        build_result(
          success: true,
          redemption: validation.existing_redemption,
          points_balance: validation.points_balance,
          error: nil
        )
      else
        build_result(
          success: false,
          error: {
            code: validation.error_code,
            message: validation.error_message
          }.compact
        )
      end
    end

    # Sync path: finalize immediately with no pre-existing reservation row.
    def finalize_without_reservation!
      finalize_with_points_debit!(points_cost_snapshot: reward.points_cost, source: nil) do |points_result|
        redemption = user.redemptions.create!(
          reward: reward,
          points_cost_snapshot: reward.points_cost,
          status: "completed",
          idempotency_key: idempotency_key
        )
        record_audit_for(redemption, change_reason: "created", point_transaction: points_result.transaction)
        redemption
      end
    end

    # Async path: finalize a previously reserved processing redemption.
    def finalize_with_reservation!(redemption)
      finalize_with_points_debit!(points_cost_snapshot: redemption.points_cost_snapshot, source: redemption) do |points_result|
        mark_redemption_completed!(redemption, point_transaction: points_result.transaction)
        redemption
      end
    end

    # Shared debit + mutation transaction used by both finalize modes.
    def finalize_with_points_debit!(points_cost_snapshot:, source:)
      points_result = nil
      redemption = nil
      ActiveRecord::Base.transaction(requires_new: true) do

        points_result =  User::PointTransactions::Create.call(
          user: user,
          amount: -points_cost_snapshot,
          kind: "redeem",
          reason_code: "reward_redemption",
          idempotency_key: idempotency_key,
          reason: "Redeemed reward #{reward.id}",
          source: source
        )
        raise ActiveRecord::Rollback unless points_result.success?
        redemption = yield(points_result)
      end

      if points_result.success?
        build_result(
          success: true,
          redemption: redemption,
          points_balance: points_result.transaction.running_balance,
          point_transaction: points_result.transaction,
          error: nil
        )
      else
        build_result(success: false, error: points_result.error)
      end
    end

    def mark_redemption_completed!(redemption, point_transaction:)
      transitioned = redemption.complete!
      raise ActiveRecord::RecordInvalid.new(redemption) unless transitioned

      record_audit_for(redemption, change_reason: "updated", point_transaction: point_transaction)
    end

    def record_audit_for(redemption, change_reason:, point_transaction: nil)
      User::Redemptions::AuditAsync.call(
        redemption: redemption,
        change_reason: change_reason,
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata,
        point_transaction: point_transaction
      )
    end

    def build_result(success:, error:, redemption: nil, points_balance: nil, point_transaction: nil)
      Result.new(
        success?: success,
        redemption: redemption,
        points_balance: points_balance,
        point_transaction: point_transaction,
        error: error
      )
    end
  end
end
