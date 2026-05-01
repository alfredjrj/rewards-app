require "rails_helper"

RSpec.describe Auditable::AuditContext do
  describe "#initialize" do
    it "normalizes origin and deep-stringifies metadata keys" do
      context = described_class.new(
        origin: :api_request,
        metadata: { request_id: 1, nested: { flow: :sync } }
      )

      expect(context.origin).to eq("api_request")
      expect(context.metadata).to eq(
        "request_id" => 1,
        "nested" => { "flow" => :sync }
      )
    end
  end

  describe "#with" do
    it "returns a new context with merged metadata" do
      context = described_class.new(
        origin: "background_job",
        metadata: { "request_id" => "req-1", "nested" => { "existing" => true } }
      )

      merged = context.with(step: "enqueue", nested: { failure: "retrying" })

      expect(merged.origin).to eq("background_job")
      expect(merged.metadata).to eq(
        "request_id" => "req-1",
        "step" => "enqueue",
        "nested" => { "failure" => "retrying" }
      )
      expect(context.metadata).to eq(
        "request_id" => "req-1",
        "nested" => { "existing" => true }
      )
    end
  end
end
