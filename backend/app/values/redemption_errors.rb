module RedemptionErrors
  INSUFFICIENT_BALANCE = {
    code: "insufficient_balance",
    message: "Insufficient points balance"
  }.freeze
  REWARD_UNAVAILABLE = {
    code: "reward_unavailable",
    message: "Reward is not available for redemption"
  }.freeze
  REDEMPTION_FINALIZED = {
    code: "redemption_finalized",
    message: "Redemption already finalized"
  }.freeze
  REDEMPTION_IN_PROGRESS = {
    code: "redemption_in_progress",
    message: "Redemption is currently processing"
  }.freeze
  RESERVATION_MISSING = {
    code: "reservation_missing",
    message: "Redemption reservation was not found"
  }.freeze
  ENQUEUE_UNAVAILABLE = {
    code: "enqueue_unavailable",
    message: "Redemption queue is temporarily unavailable. Please try again."
  }.freeze
  VALIDATION_ERROR = {
    code: "validation_error",
    message: "Redemption is invalid"
  }.freeze
  INTERNAL_ERROR = {
    code: "internal_error",
    message: "Unable to redeem reward after retries"
  }.freeze
  INTERNAL_ERROR_PUBLIC_MESSAGE = "Unable to process redemption right now. Please try again.".freeze

  TRANSIENT_CODES = %w[enqueue_unavailable internal_error].freeze
  USER_VISIBLE_CODES = %w[
    insufficient_balance
    reward_unavailable
    redemption_finalized
    redemption_in_progress
    reservation_missing
    validation_error
  ].freeze
  SANITIZED_CODES = %w[enqueue_unavailable internal_error].freeze

  def self.transient?(code)
    TRANSIENT_CODES.include?(code.to_s)
  end

  def self.user_visible_code?(code)
    USER_VISIBLE_CODES.include?(code.to_s)
  end

  def self.sanitized_code?(code)
    SANITIZED_CODES.include?(code.to_s)
  end
end
