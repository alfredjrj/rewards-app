require "rails_helper"

RSpec.describe Idempotency::KeyValidator do
  describe ".call" do
    it "returns valid key when header value is valid" do
      result = described_class.call(raw_header_value: "abc-123_DEF")

      expect(result.valid?).to be(true)
      expect(result.key).to eq("abc-123_DEF")
      expect(result.error).to be_nil
    end

    it "trims surrounding whitespace for valid key" do
      result = described_class.call(raw_header_value: "  abc-123  ")

      expect(result.valid?).to be(true)
      expect(result.key).to eq("abc-123")
    end

    it "returns required error for blank key" do
      result = described_class.call(raw_header_value: "   ")

      expect(result.valid?).to be(false)
      expect(result.key).to be_nil
      expect(result.error).to eq(
        code: "idempotency_key_required",
        message: "Idempotency-Key header is required"
      )
    end

    it "returns invalid format error for malformed key" do
      result = described_class.call(raw_header_value: "bad key with spaces")

      expect(result.valid?).to be(false)
      expect(result.key).to be_nil
      expect(result.error).to eq(
        code: "invalid_idempotency_key",
        message: "Idempotency-Key must be 1-128 chars of letters, numbers, underscore, or dash"
      )
    end
  end
end
