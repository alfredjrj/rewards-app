module User::Redemptions
  # Cache + Action Cable for async redemption request status (used by Process and after Sidekiq gives up).
  class StatusPublisher
    CACHE_PREFIX = "redemption_request_status:user".freeze
    CHANNEL_PREFIX = "user_redemptions".freeze
    CACHE_TTL = 10.minutes

    def self.publish(user_id:, request_id:, payload:)
      Rails.cache.write(cache_key(user_id: user_id, request_id: request_id), payload, expires_in: CACHE_TTL)
      ActionCable.server.broadcast(channel_name(user_id: user_id), payload)
    end

    def self.read(user_id:, request_id:)
      Rails.cache.read(cache_key(user_id: user_id, request_id: request_id))
    end

    def self.cache_key(user_id:, request_id:)
      "#{CACHE_PREFIX}:#{user_id}:#{request_id}"
    end

    def self.channel_name(user_id:)
      "#{CHANNEL_PREFIX}:#{user_id}"
    end
  end
end
