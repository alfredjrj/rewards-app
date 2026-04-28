module User::Redemptions
  # Runs async redemption after enqueue: Create + publish status for polling/cable.
  # Raises TransientFailure when Sidekiq should retry (infra or internal_error from Create).
  class Process
    TransientFailure = Class.new(StandardError)
    TERMINAL_STATUSES = %w[completed failed cancelled].freeze

    INFRA_TRANSIENT_EXCEPTIONS = [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::Deadlocked,
      ActiveRecord::LockWaitTimeout,
      ActiveRecord::SerializationFailure
    ].freeze

    RETRYABLE_SERVICE_ERROR_CODES = %w[internal_error].freeze

    def self.call(user_id:, reward_id:, request_id:, job_id: nil)
      new(user_id: user_id, reward_id: reward_id, request_id: request_id, job_id: job_id).call
    end

    def self.finalize_after_retries_exhausted(sidekiq_msg, exception)
      user_id, reward_id, request_id = Array(sidekiq_msg["args"])
      return if user_id.blank? || request_id.blank?
      updated = mark_redemption_status(user_id: user_id, request_id: request_id, status: "failed")
      return unless updated

      payload = {
        request_id: request_id,
        reward_id: reward_id,
        status: "failed",
        error: {
          code: "internal_error",
          message: "Unable to redeem reward after retries"
        }
      }
      StatusPublisher.publish(user_id: user_id, request_id: request_id, payload: payload)
      Rails.logger.error(
        "[redemption.process_job] retries_exhausted jid=#{sidekiq_msg['jid']} user_id=#{user_id} " \
        "reward_id=#{reward_id} request_id=#{request_id} error=#{exception.class}: #{exception.message}"
      )
    end

    def initialize(user_id:, reward_id:, request_id:, job_id:)
      @user_id = user_id
      @reward_id = reward_id
      @request_id = request_id
      @job_id = job_id
    end

    def call
      log :info, "started"

      begin
        user = User.find(@user_id)
        reward = Reward.find(@reward_id)

        result = User::Redemptions::Create.call(
          user: user,
          reward: reward,
          idempotency_key: @request_id
        )

        if result.success?
          publish_status(user_id: user.id, reward_id: result.redemption.reward_id, status: "completed", error: nil)
          log :info, "completed", user_id: user.id, reward_id: reward.id
          return
        end

        raise TransientFailure, "Transient redemption processing failure" if retryable_service_error?(result.error)

        self.class.mark_redemption_status(user_id: user.id, request_id: @request_id, status: "failed")
        publish_status(user_id: user.id, reward_id: reward.id, status: "failed", error: result.error)
        log :warn, "failed", user_id: user.id, reward_id: reward.id, error: result.error&.dig(:code)
      rescue ActiveRecord::RecordNotFound => e
        self.class.mark_redemption_status(user_id: @user_id, request_id: @request_id, status: "failed")
        publish_status(
          user_id: @user_id,
          reward_id: @reward_id,
          status: "failed",
          error: {
            code: "not_found",
            message: "User or reward was removed before redemption could finish",
            details: { model: e.model }
          }.compact
        )
        log :warn, "not_found", user_id: nil, reward_id: nil, error: e.message
      rescue StandardError => e
        if transient_infrastructure_error?(e)
          log :warn, "transient_failure", error: "#{e.class}: #{e.message}"
          raise TransientFailure, e.message
        end

        raise
      end
    end

    def self.mark_redemption_status(user_id:, request_id:, status:)
      redemption = User::Redemption.find_by(user_id: user_id, idempotency_key: request_id)
      return false unless redemption
      return false if TERMINAL_STATUSES.include?(redemption.status)
      return false if redemption.status == status

      redemption.update!(status: status)
      true
    end

    private

    def publish_status(user_id:, reward_id:, status:, error:)
      payload = {
        request_id: @request_id,
        reward_id: reward_id,
        status: status,
        error: error
      }.compact
      StatusPublisher.publish(user_id: user_id, request_id: @request_id, payload: payload)
    end

    def retryable_service_error?(error)
      code = error&.dig(:code)
      code.present? && RETRYABLE_SERVICE_ERROR_CODES.include?(code)
    end

    def transient_infrastructure_error?(exception)
      return true if INFRA_TRANSIENT_EXCEPTIONS.any? { |klass| exception.is_a?(klass) }

      defined?(Redis::BaseConnectionError) && exception.is_a?(Redis::BaseConnectionError)
    end

    def log(level, event, user_id: nil, reward_id: nil, error: nil)
      Rails.logger.public_send(level, "[redemption.process_job] #{event} #{log_suffix(user_id: user_id, reward_id: reward_id, error: error)}")
    end

    def log_suffix(user_id:, reward_id:, error:)
      [
        "jid=#{@job_id}",
        "user_id=#{user_id || @user_id}",
        "reward_id=#{reward_id || @reward_id}",
        "request_id=#{@request_id}",
        ("error=#{error}" if error)
      ].compact.join(" ")
    end
  end
end
