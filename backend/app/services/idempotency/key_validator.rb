module Idempotency
  class KeyValidator
    KEY_RE = /\A[A-Za-z0-9_-]{1,128}\z/
    Result = Struct.new(:valid?, :key, :error, keyword_init: true)

    def self.call(raw_header_value:)
      key = raw_header_value.to_s.strip
      return Result.new(valid?: false, key: nil, error: missing_error) if key.empty?
      return Result.new(valid?: false, key: nil, error: invalid_error) unless key.match?(KEY_RE)

      Result.new(valid?: true, key: key, error: nil)
    end

    def self.missing_error
      {
        code: "idempotency_key_required",
        message: "Idempotency-Key header is required"
      }
    end

    def self.invalid_error
      {
        code: "invalid_idempotency_key",
        message: "Idempotency-Key must be 1-128 chars of letters, numbers, underscore, or dash"
      }
    end
  end
end
