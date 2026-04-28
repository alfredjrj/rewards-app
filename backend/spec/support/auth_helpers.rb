module AuthHelpers
  def fetch_csrf_token_for(user, path: "/api/v1/user")
    sign_in user
    get path
    token = JSON.parse(response.body).dig("meta", "csrf_token")
    sign_in user
    token
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
