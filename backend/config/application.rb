require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use a standard Rails app with sessions enabled (not API-only)
    # This is needed for cookie-based OAuth authentication
    config.middleware.use ActionDispatch::Cookies

    # External API endpoint configuration
    config.api_endpoints = ActiveSupport::OrderedOptions.new
    config.api_endpoints.scryfall_base = "https://api.scryfall.com"
    config.api_endpoints.edhrec_base = "https://edhrec.com"
    config.api_endpoints.edhrec_json = "https://json.edhrec.com"

    # Honour the PUBLIC_API_PATH env var so that generated URLs (redirects,
    # url_for, etc.) include the API path prefix. When the var is absent
    # (local dev without Docker) ENV returns nil, which is Rails' default
    # — no behaviour change.
    config.relative_url_root = ENV["PUBLIC_API_PATH"]
  end
end
