# Allowlist browser origins that may call this API with cookies.
# Set FRONTEND_ORIGINS="http://localhost:3000" or comma-separated URLs (see backend/.env.example).
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allowed_origins = ENV["FRONTEND_ORIGINS"].presence || "http://localhost:3000"
    origins allowed_origins.split(",").map(&:strip).reject(&:blank?)

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: true
  end
end
