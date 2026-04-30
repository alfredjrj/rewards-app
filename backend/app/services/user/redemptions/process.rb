module User::Redemptions
  # Runs async redemption after reservation: Create + publish status for polling/cable.
  # Raises TransientFailure when Sidekiq should retry (infra or internal_error from Create).
  class Process
    TransientFailure = Class.new(StandardError)

    INFRA_TRANSIENT_EXCEPTIONS = [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::Deadlocked,
      ActiveRecord::LockWaitTimeout,
      ActiveRecord::SerializationFailure
    ].freeze

    RETRYABLE_SERVICE_ERROR_CODES = %w[internal_error].freeze

    def self.call(user_id:, reward_id:, request_id:, job_id: nil, change_source_origin: "background_job", change_source_metadata: {})
      new(
        user_id: user_id,
        reward_id: reward_id,
        request_id: request_id,
        job_id: job_id,
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      ).call
    end

    def self.finalize_after_retries_exhausted(
      user_id:,
      reward_id:,
      request_id:,
      change_source_origin: "background_job",
      change_source_metadata: {}
    )
      return if user_id.blank? || request_id.blank?
      updated = User::Redemptions::StatusTransition.mark(
        user_id: user_id,
        request_id: request_id,
        status: "failed",
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
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
    end

    def initialize(user_id:, reward_id:, request_id:, job_id:, change_source_origin: "background_job", change_source_metadata: {})
      @user_id = user_id
      @reward_id = reward_id
      @request_id = request_id
      @job_id = job_id
      @change_source_origin = change_source_origin
      @change_source_metadata = change_source_metadata
    end

    def call
      log :info, "started"

      begin
        user = User.find(user_id)
        reward = Reward.find(reward_id)

        result = User::Redemptions::Create.call(
          user: user,
          reward: reward,
          idempotency_key: request_id,
          change_source_origin: change_source_origin,
          change_source_metadata: change_source_metadata
        )

        return handle_create_success(user, reward, result) if result.success?

        handle_create_failure(user, reward, result)
      rescue ActiveRecord::RecordNotFound => exception
        handle_record_not_found(exception)
      rescue StandardError => exception
        raise_transient_failure_if_needed(exception)
        raise
      end
    end

    private
    attr_reader :user_id, :reward_id, :request_id, :job_id, :change_source_origin, :change_source_metadata

    def handle_create_success(user, reward, result)
      publish_status(
        user_id: user.id,
        reward_id: result.redemption.reward_id,
        status: "completed",
        error: nil
      )
      log :info, "completed", user_id: user.id, reward_id: reward.id
    end

    def handle_create_failure(user, reward, result)
      raise TransientFailure, "Transient redemption processing failure" if retryable_service_error?(result.error)

      User::Redemptions::StatusTransition.mark(
        user_id: user.id,
        request_id: request_id,
        status: "failed",
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
      publish_status(user_id: user.id, reward_id: reward.id, status: "failed", error: result.error)
      log :warn, "failed", user_id: user.id, reward_id: reward.id, error: result.error&.dig(:code)
    end

    def handle_record_not_found(exception)
      User::Redemptions::StatusTransition.mark(
        user_id: user_id,
        request_id: request_id,
        status: "failed",
        change_source_origin: change_source_origin,
        change_source_metadata: change_source_metadata
      )
      publish_status(
        user_id: user_id,
        reward_id: reward_id,
        status: "failed",
        error: {
          code: "not_found",
          message: "User or reward was removed before redemption could finish",
          details: { model: exception.model }
        }.compact
      )
      log :warn, "not_found", user_id: nil, reward_id: nil, error: exception.message
    end

    def raise_transient_failure_if_needed(exception)
      return unless transient_infrastructure_error?(exception)

      log :warn, "transient_failure", error: "#{exception.class}: #{exception.message}"
      raise TransientFailure, exception.message
    end

    def publish_status(user_id:, reward_id:, status:, error:)
      payload = {
        request_id: request_id,
        reward_id: reward_id,
        status: status,
        error: error
      }.compact
      StatusPublisher.publish(user_id: user_id, request_id: request_id, payload: payload)
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
        "jid=#{job_id}",
        "user_id=#{user_id || self.user_id}",
        "reward_id=#{reward_id || self.reward_id}",
        "request_id=#{request_id}",
        ("error=#{error}" if error)
      ].compact.join(" ")
    end
  end
end
