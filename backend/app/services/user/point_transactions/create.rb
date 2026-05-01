# Ledger-style point accounting: each change is an immutable row with amount and a denormalized
# running_balance snapshot. That beats the main alternative—a single mutable points counter on User—
# because we keep a full audit trail (kind/reason/source), enforce non-negative balances from history,
# and reuse idempotency keys per movement without guessing “current balance” under retries. Appending
# rows plus user-level locking stays correct under concurrency; a lone counter cannot explain *why*
# the balance changed or replay safely after partial failures.
module User::PointTransactions
  class Create < ApplicationService

    def initialize(user:, amount:, kind:, reason_code:, idempotency_key:, reason: nil, source: nil)
      @user = user
      @amount = amount
      @kind = kind
      @reason_code = reason_code
      @idempotency_key = idempotency_key
      @reason = reason
      @source = source
    end

    def call
      log(:info, "started")

      # Lock this user while updating points so two requests cannot calculate
      # and save a new balance at the same time.
      user.with_lock do
        existing = find_existing_transaction
        if existing
          log(:info, "idempotent_hit", transaction_id: existing.id, running_balance: existing.running_balance)
          return success(existing)
        end

        current_balance = latest_running_balance
        next_balance = current_balance + amount
        return failure(**RedemptionErrors::INSUFFICIENT_BALANCE) if next_balance.negative?

        transaction = User::PointTransaction.create!(
          user: user,
          amount: amount,
          running_balance: next_balance,
          kind: kind,
          reason_code: reason_code,
          idempotency_key: idempotency_key,
          reason: reason,
          source: source
        )

        log(:info, "succeeded", transaction_id: transaction.id, running_balance: transaction.running_balance)
        success(transaction)
      end
    rescue ActiveRecord::RecordInvalid => e
      log(:warn, "validation_failed", error_class: e.class.name)
      Rails.logger.warn(e.full_message)
      failure(
        **RedemptionErrors::VALIDATION_ERROR.merge(message: "Point transaction is invalid"),
        details: e.record.errors.to_hash(true)
      )
    end

    private

    attr_reader :user, :amount, :kind, :reason_code, :idempotency_key, :reason, :source

    def find_existing_transaction
      user.point_transactions.find_by(idempotency_key: idempotency_key)
    end

    def latest_running_balance
      user.current_points_balance
    end

    def success(transaction)
      ServiceResult.success(point_transaction: transaction, transaction: transaction)
    end

    def failure(code:, message:, details: nil)
      ServiceResult.failure(code: code, message: message, details: details)
    end

    def log(level, event, extra = {})
      Rails.logger.public_send(level, {
        service: self.class.name,
        event: event,
        user_id: user.id,
        amount: amount,
        kind: kind,
        reason_code: reason_code,
        idempotency_key: idempotency_key
      }.merge(extra).to_json)
    end
  end
end
