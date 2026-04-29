class Rack::Attack
  # Keep throttling opt-in for test so request specs stay deterministic.
  self.enabled = !Rails.env.test?

  self.cache.store = if Rails.env.test?
    ActiveSupport::Cache::MemoryStore.new
  else
    Rails.cache
  end

  # Limit brute-force attempts for the same email from one IP.
  throttle("auth/login_email_ip", limit: 5, period: 1.minute) do |req|
    next unless req.post? && req.path == "/users/sign_in"

    email = begin
      from_params = req.params.dig("user", "email")
      if from_params.present?
        from_params
      else
        raw_body = req.body.read
        req.body.rewind
        JSON.parse(raw_body).dig("user", "email")
      end
    rescue JSON::ParserError
      nil
    end
    email = email.to_s.strip.downcase
    next if email.blank?

    "#{email}:#{req.ip}"
  end

  # Fallback throttle to slow broad IP-based credential stuffing.
  throttle("auth/login_ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.post? && req.path == "/users/sign_in"
  end

  # Bound account-creation spam by source IP.
  throttle("auth/signup_ip", limit: 5, period: 1.hour) do |req|
    req.ip if req.post? && req.path == "/users"
  end

  self.throttled_responder = lambda do |request|
    now = Time.current
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period].to_i - (now.to_i % match_data[:period].to_i)) rescue 60
    body = {
      error: {
        code: "rate_limited",
        message: "Too many requests. Please try again later."
      }
    }.to_json

    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [ body ]
    ]
  end
end
