module User::Redemptions
  # Runs async redemption after enqueue: Create + publish status for polling/cable.
  # Raises TransientFailure when Sidekiq should retry (infra or internal_error from Create).
  # Releases PendingPoints on terminal outcomes only (success, non-retryable failure, not_found,
  # retries exhausted)—not while Sidekiq is still retrying, so Redis holds stay aligned with jobs.
  class Process
    TransientFailure = Class.new(StandardError)

    INFRA_TRANSIENT_EXCEPTIONS = [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::Deadlocked,
      ActiveRecord::LockWaitTimeout,
      ActiveRecord::SerializationFailure,
    ].freeze

    RETRYABLE_SERVICE_ERROR_CODES = %w[internal_error].freeze

    def self.call(user_id:, reward_id:, request_id:, job_id: nil)
      new(user_id: user_id, reward_id: reward_id, request_id: request_id, job_id: job_id).call
    end

    def self.finalize_after_retries_exhausted(sidekiq_msg, exception)
      user_id, reward_id, request_id = Array(sidekiq_msg["args"])
      return if user_id.blank? || request_id.blank?

      PendingPoints.release!(user_id: user_id, request_id: request_id)

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
          PendingPoints.release!(user_id: user.id, request_id: @request_id)
          publish_status(user_id: user.id, reward_id: result.redemption.reward_id, status: "completed", error: nil)
          log :info, "completed", user_id: user.id, reward_id: reward.id
          return
        end

        raise TransientFailure, "Transient redemption processing failure" if retryable_service_error?(result.error)

        PendingPoints.release!(user_id: user.id, request_id: @request_id)
        publish_status(user_id: user.id, reward_id: reward.id, status: "failed", error: result.error)
        log :warn, "failed", user_id: user.id, reward_id: reward.id, error: result.error&.dig(:code)
      rescue ActiveRecord::RecordNotFound => e
        PendingPoints.release!(user_id: @user_id, request_id: @request_id)
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
