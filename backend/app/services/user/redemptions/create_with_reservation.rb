module User::Redemptions
  # Async redemption: completes a `processing` row that was reserved earlier by
  # `PlaceCreditHoldAndReserve`. Used by external providers (e.g. ticketmaster).
  class CreateWithReservation < CreateBase
    private

    def pre_finalize_guard(existing_redemption)
      # Async flow requires an upstream reservation; refuse if missing.
      return nil if existing_redemption

      failure("reservation_missing", "Redemption reservation was not found")
    end

    def finalize!(redemption)
      points_result = nil
      ActiveRecord::Base.transaction(requires_new: true) do
        points_result = create_points_debit_for(
          points_cost_snapshot: redemption.points_cost_snapshot,
          source: redemption
        )
        raise ActiveRecord::Rollback unless points_result.success?

        mark_redemption_completed!(redemption, point_transaction: points_result.transaction)
      end

      return failure_from_points_result(points_result) unless points_result.success?

      success(redemption, points_result.transaction.running_balance, points_result.transaction)
    end

    def mark_redemption_completed!(redemption, point_transaction:)
      transitioned = redemption.complete!
      raise ActiveRecord::RecordInvalid.new(redemption) unless transitioned

      record_audit_for(redemption, change_reason: "updated", point_transaction: point_transaction)
    end
  end
end
