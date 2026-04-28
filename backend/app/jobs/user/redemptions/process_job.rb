class User::Redemptions::ProcessJob
  include Sidekiq::Job
  # Use `default` so `bundle exec sidekiq` picks up jobs without `-q redemptions`.
  sidekiq_options queue: :default, retry: 5, backtrace: 5

  class TransientRedemptionError < StandardError; end

  sidekiq_retries_exhausted do |msg, ex|
    handle_retries_exhausted(msg, ex)
  end

  def perform(user_id, reward_id, idempotency_key)
    User::Redemptions::Process.call(
      user_id: user_id,
      reward_id: reward_id,
      request_id: idempotency_key,
      job_id: jid
    )
  rescue User::Redemptions::Process::TransientFailure => e
    Rails.logger.warn(
      "[redemption.process_job] transient_failure jid=#{jid} user_id=#{user_id} reward_id=#{reward_id} " \
      "request_id=#{idempotency_key} error=#{e.message}"
    )
    raise TransientRedemptionError, e.message
  end

  def self.handle_retries_exhausted(sidekiq_msg, exception)
    user_id, reward_id, request_id = Array(sidekiq_msg["args"])
    return if user_id.blank? || request_id.blank?

    User::Redemptions::Process.finalize_after_retries_exhausted(
      user_id: user_id,
      reward_id: reward_id,
      request_id: request_id
    )
    Rails.logger.error(
      "[redemption.process_job] retries_exhausted jid=#{sidekiq_msg['jid']} user_id=#{user_id} " \
      "reward_id=#{reward_id} request_id=#{request_id} error=#{exception.class}: #{exception.message}"
    )
  end
end
