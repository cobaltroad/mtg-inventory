require "test_helper"

class OmniAuthConfigurationTest < ActionDispatch::IntegrationTest
  test "OmniAuth is configured with Discord provider" do
    assert_defined OmniAuth::Strategies::Discord
    providers = OmniAuth::Builder.new(nil).instance_variable_get(:@providers)
    discord_provider = providers.find { |p| p.is_a?(OmniAuth::Strategies::Discord) }
    assert_not_nil discord_provider, "Discord provider should be configured"
  end

  test "auth/discord route redirects to Discord OAuth" do
    get "/auth/discord"
    assert_response :redirect
  end

  test "auth/status returns JSON with authenticated status" do
    get "/auth/status"
    assert_response :success
    body = JSON.parse(response.body)
    assert_includes body, "authenticated"
    assert_equal false, body["authenticated"]
  end
end
