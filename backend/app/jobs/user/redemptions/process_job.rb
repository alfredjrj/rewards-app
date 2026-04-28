class User::Redemptions::ProcessJob
  include Sidekiq::Job
  # Use `default` so `bundle exec sidekiq` picks up jobs without `-q redemptions`.
  sidekiq_options queue: :default, retry: 5, backtrace: 5

  class TransientRedemptionError < StandardError; end

  sidekiq_retries_exhausted do |msg, ex|
    User::Redemptions::FinalizeProcessing.finalize_after_retries_exhausted(msg, ex)
  end

  def perform(user_id, reward_id, idempotency_key)
    User::Redemptions::FinalizeProcessing.call(
      user_id: user_id,
      reward_id: reward_id,
      request_id: idempotency_key,
      job_id: jid
    )
  rescue User::Redemptions::FinalizeProcessing::TransientFailure => e
    Rails.logger.warn(
      "[redemption.process_job] transient_failure jid=#{jid} user_id=#{user_id} reward_id=#{reward_id} " \
      "request_id=#{idempotency_key} error=#{e.message}"
    )
    raise TransientRedemptionError, e.message
  end
end
