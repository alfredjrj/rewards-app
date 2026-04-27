require "rails_helper"

RSpec.describe Api::V1::User::ProfileSerializer do
  it "serializes user profile payload" do
    user = create(:user)

    payload = Api::V1::User::ProfileSerializer.call(user: user)

    expect(payload).to eq(
      data: {
        id: user.id,
        email: user.email
      }
    )
  end
end
