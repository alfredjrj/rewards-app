module User::Redemptions
  # In-flight point holds for async redemptions (HTTP 202 → Sidekiq debits the ledger later).
  #
  # Why Redis, not Postgres alone?
  # - Ledger rows appear only when +User::Redemptions::Create+ runs in the job; until then there is
  #   no debit, so SQL cannot answer “how much is reserved while processing?”
  # - We need an ephemeral counter that updates as soon as the client submits. Redis (TTL on claims,
  #   INCRBY for per-user totals) matches that and uses the same +REDIS_URL+ as Sidekiq; +Rails.cache+
  #   is often memory/null in dev/test.
  # - One claim per +Idempotency-Key+ (+SET NX+): duplicate submits do not double-count; +release!+
  #   is idempotent once the claim key is gone.
  #
  # On Redis errors: reserve/read degrade (no hold; pending reads as 0) so APIs keep responding;
  # spendable points may be overstated briefly.
  class PendingPoints
    CLAIM_PREFIX = "rp:claim:v1:"
    TOTAL_PENDING_PREFIX = "rp:pending:user:v1:"
    CLAIM_TTL_SECONDS = 24.hours.to_i
    RELEASE_CLAIM_LUA = <<~LUA.freeze
      local claim_key = KEYS[1]
      local total_key = KEYS[2]
      local claim_points = redis.call("GET", claim_key)
      if not claim_points then
        return 0
      end

      redis.call("DEL", claim_key)
      local new_total = redis.call("DECRBY", total_key, claim_points)
      if new_total < 0 then
        redis.call("SET", total_key, 0)
        new_total = 0
      end

      return new_total
    LUA

    REDIS_ERRORS = [ Redis::BaseConnectionError, Redis::TimeoutError ].freeze

    class << self
      # True if this call created a new claim (first use of that idempotency key).
      # False if the claim already existed, arguments were invalid, or Redis failed.
      def reserve!(user_id:, request_id:, points:)
        pts = points.to_i
        return false unless reserve_args_valid?(pts, user_id, request_id)

        redis_guard(false) { |r| reserve_new_claim(r, user_id: user_id, request_id: request_id, points: pts) }
      end

      # Drops one hold after a terminal job outcome. Safe to call repeatedly for the same +request_id+.
      def release!(user_id:, request_id:)
        return if user_id.blank? || request_id.blank?

        redis_guard(nil) { |r| release_claim_if_present(r, user_id: user_id, request_id: request_id) }
      end

      # Sum of points still reserved for in-flight redemptions for this user.
      def pending_total_for(user_id:)
        return 0 if user_id.blank?

        redis_guard(0) { |r| read_pending_total(r, user_id: user_id) }
      end

      private

      def reserve_args_valid?(points, user_id, request_id)
        points.positive? && user_id.present? && request_id.present?
      end

      def reserve_new_claim(redis, user_id:, request_id:, points:)
        claim = claim_key(request_id)
        created = redis.set(claim, points, nx: true, ex: CLAIM_TTL_SECONDS)
        return false unless created

        redis.incrby(total_pending_key(user_id), points)
        true
      end

      def release_claim_if_present(redis, user_id:, request_id:)
        claim = claim_key(request_id)
        redis.eval(RELEASE_CLAIM_LUA, keys: [ claim, total_pending_key(user_id) ], argv: [])
      end

      def read_pending_total(redis, user_id:)
        (redis.get(total_pending_key(user_id)) || 0).to_i
      end

      def redis_guard(fallback)
        yield connection
      rescue *REDIS_ERRORS => e
        log_redis_error(e)
        fallback
      end

      def log_redis_error(error)
        Rails.logger.warn("[pending_points] redis error #{error.class}: #{error.message}")
      end

      def claim_key(request_id)
        "#{CLAIM_PREFIX}#{request_id}"
      end

      def total_pending_key(user_id)
        "#{TOTAL_PENDING_PREFIX}#{user_id}"
      end

      def redis_url
        ENV.fetch("REDIS_URL", "redis://localhost:6379/7")
      end

      def connection
        @connection ||= Redis.new(url: redis_url, reconnect_attempts: 2)
      end
    end
  end
end
