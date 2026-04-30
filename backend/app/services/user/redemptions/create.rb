module User::Redemptions
  # Sync redemption: completes inline in a single step, with NO prior `processing` hold.
  # Used for `internal` provider rewards where fulfillment is immediate.
  class Create < CreateBase
    private

    def pre_finalize_guard(existing_redemption)
      # Sync flow assumes nothing exists for this idempotency key yet.
      # A non-terminal row (`processing`) means an async flow is mid-flight; refuse to double up.
      return nil unless existing_redemption

      failure("redemption_in_progress", "Redemption is currently processing")
    end

    def finalize!(_existing_redemption)
      points_result = create_points_debit_for(points_cost_snapshot: reward.points_cost, source: nil)
      return failure_from_points_result(points_result) unless points_result.success?

      redemption = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        redemption = user.redemptions.create!(
          reward: reward,
          points_cost_snapshot: reward.points_cost,
          status: "completed",
          idempotency_key: idempotency_key
        )
        record_audit_for(redemption, change_reason: "created", point_transaction: points_result.transaction)
      end

      success(redemption, points_result.transaction.running_balance, points_result.transaction)
    end
  end
end
