require "rails_helper"

RSpec.describe Api::V1::RewardCursorMetaSerializer do
  it "serializes Pagy Keyset pagination metadata" do
    pagy = instance_double(Pagy::Keyset)
    allow(pagy).to receive_messages(limit: 6, next: "opaque-next-token")

    payload = described_class.call(pagy: pagy)

    expect(payload).to eq(
      per_page: 6,
      next_cursor: "opaque-next-token",
      has_next: true
    )
  end

  it "reports no next page when pagy.next is absent" do
    pagy = instance_double(Pagy::Keyset)
    allow(pagy).to receive_messages(limit: 6, next: nil)

    payload = described_class.call(pagy: pagy)

    expect(payload[:has_next]).to be(false)
    expect(payload[:next_cursor]).to be_nil
  end
end
