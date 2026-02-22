require "vcr"
require "webmock"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri]
  }
end

if Rails.env.test?
  base_url = Rails.application.config.api_endpoints.scryfall_base
  edhrec_base = Rails.application.config.api_endpoints.edhrec_base
  edhrec_json = Rails.application.config.api_endpoints.edhrec_json

  $stderr.puts "VCR Setup: Configuring test endpoints - Scryfall: #{base_url}, EDHREC: #{edhrec_base}"

  WebMock.enable!
  WebMock.disable_net_connect!(allow_localhost: true)

  # Add catch-all stubs using string patterns (more reliable than regex in WebMock)
  # Using to_uri + path prefix matching
  WebMock.stub_request(:get, /.*test-scryfall.*/)
    .to_return(status: 200, body: '{"object":"list","data":[],"has_more":false}', headers: { "Content-Type" => "application/json" })
  
  WebMock.stub_request(:get, /.*test-edhrec.*/)
    .to_return(status: 200, body: '<html><body></body></html>', headers: { "Content-Type" => "text/html" })

  # Backward compatibility stubs
  WebMock.stub_request(:get, /.*api\.scryfall.*/)
    .to_return(status: 200, body: '{"object":"list","data":[],"has_more":false}', headers: { "Content-Type" => "application/json" })

  $stderr.puts "VCR Setup: Catch-all stubs registered with wildcard patterns"
else
  WebMock.disable_net_connect!(allow_localhost: true)
end
