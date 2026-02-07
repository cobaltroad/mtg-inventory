require "vcr"

VCR.configure do |config|
  # Store cassettes in test/fixtures/vcr_cassettes
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"

  # Use webmock as the stubbing library
  config.hook_into :webmock

  # Allow connections to localhost for test server
  config.ignore_localhost = true

  # Configure request matching
  config.default_cassette_options = {
    record: :once,  # Record only if cassette doesn't exist
    match_requests_on: [ :method, :uri ]
  }
end
