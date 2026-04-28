require "rails_helper"

RSpec.describe User::Redemptions::PendingPoints do
  let(:redis) { instance_double(Redis) }

  before do
    described_class.instance_variable_set(:@connection, redis)
  end

  after do
    described_class.remove_instance_variable(:@connection) if described_class.instance_variable_defined?(:@connection)
  end

  describe ".reserve!" do
    it "sets claim and increments total on first idempotency use" do
      allow(redis).to receive(:set).with("rp:claim:v1:req-1", 100, nx: true, ex: described_class::CLAIM_TTL_SECONDS).and_return(true)
      allow(redis).to receive(:incrby).with("rp:pending:user:v1:42", 100).and_return(100)

      expect(described_class.reserve!(user_id: 42, request_id: "req-1", points: 100)).to be(true)
    end

    it "does not increment total when claim already exists" do
      allow(redis).to receive(:set).with("rp:claim:v1:req-1", 100, nx: true, ex: described_class::CLAIM_TTL_SECONDS).and_return(false)

      expect(described_class.reserve!(user_id: 42, request_id: "req-1", points: 100)).to be(false)
      expect(redis).not_to receive(:incrby)
    end
  end

  describe ".release!" do
    it "atomically releases claim and decrements total via Lua" do
      allow(redis).to receive(:eval).and_return(0)

      described_class.release!(user_id: 42, request_id: "req-1")

      expect(redis).to have_received(:eval).with(
        described_class::RELEASE_CLAIM_LUA,
        keys: [ "rp:claim:v1:req-1", "rp:pending:user:v1:42" ],
        argv: []
      )
    end

    it "no-ops when claim is missing" do
      allow(redis).to receive(:eval).and_return(0)

      described_class.release!(user_id: 42, request_id: "req-1")

      expect(redis).to have_received(:eval).with(
        described_class::RELEASE_CLAIM_LUA,
        keys: [ "rp:claim:v1:req-1", "rp:pending:user:v1:42" ],
        argv: []
      )
    end
  end

  describe ".pending_total_for" do
    it "returns stored total" do
      allow(redis).to receive(:get).with("rp:pending:user:v1:42").and_return("150")

      expect(described_class.pending_total_for(user_id: 42)).to eq(150)
    end
  end
end
