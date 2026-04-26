module User::PointTransactions
  class Create
    Result = Struct.new(:success?, :transaction, :error, keyword_init: true)

    def self.call(...)
      new(...).call
    end

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
        return failure("insufficient_balance", "Insufficient points balance") if next_balance.negative?

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
      failure(
        "validation_error",
        "Point transaction is invalid",
        details: e.record.errors.to_hash(true)
      )
    rescue StandardError => e
      log(:error, "failed", error_class: e.class.name, error_message: e.message)
      failure("internal_error", "Unable to create point transaction")
    end

    private

    attr_reader :user, :amount, :kind, :reason_code, :idempotency_key, :reason, :source

    def find_existing_transaction
      user.point_transactions.find_by(idempotency_key: idempotency_key)
    end

    def latest_running_balance
      user.point_transactions.order(created_at: :desc, id: :desc).pick(:running_balance) || 0
    end

    def success(transaction)
      Result.new(success?: true, transaction: transaction, error: nil)
    end

    def failure(code, message, details: nil)
      Result.new(
        success?: false,
        transaction: nil,
        error: {
          code: code,
          message: message,
          details: details
        }.compact
      )
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
