require "rails_helper"

RSpec.describe Api::V1::PaginationMetaSerializer do
  it "serializes pagy metadata payload" do
    pagy = double("pagy", page: 2, limit: 10, count: 35, pages: 4)

    payload = Api::V1::PaginationMetaSerializer.call(pagy: pagy)

    expect(payload).to eq(
      page: 2,
      per_page: 10,
      total_count: 35,
      total_pages: 4
    )
  end
end
