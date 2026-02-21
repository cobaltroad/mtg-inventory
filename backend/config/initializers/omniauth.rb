# Only configure OmniAuth in production
if ENV.fetch("RAILS_ENV", "development") == "production"
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :discord, ENV["DISCORD_CLIENT_ID"], ENV["DISCORD_CLIENT_SECRET"], scope: "identify email"
  end
end
