ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "json"

# Load VCR setup if present
vcr_setup = File.expand_path("support/vcr_setup.rb", __dir__)
require vcr_setup if File.exist?(vcr_setup)

# ---------------------------------------------------------------------------
# Minitest 6 removed Object#stub (it was extracted to a separate gem that
# treats any value responding to :call as a factory, which breaks stubs on
# objects that legitimately have a #call method).  This minimal
# implementation unconditionally returns the replacement value, matching the
# behaviour the test suite expects.
# ---------------------------------------------------------------------------
class Object
  def stub(name, value)
    metaclass = singleton_class
    original = method(name)
    metaclass.define_method(name) { |*_a, **_kw, &_b| value }
    yield self
  ensure
    metaclass.define_method(name, original)
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # Comment out for now since we don't have a comprehensive fixture set
    # fixtures :all

    # Add more helper methods to be used by all tests here...

    # ---------------------------------------------------------------------------
    # JSON log parsing helpers for structured logging tests
    # ---------------------------------------------------------------------------

    # Parse all JSON log entries from a log string
    # Returns an array of parsed JSON objects (hashes)
    def parse_json_logs(log_string)
      log_string.split("\n").filter_map do |line|
        # Skip empty lines
        next if line.strip.empty?

        # Extract JSON portion from log line
        # Rails logger format: "I, [timestamp #pid]  LEVEL -- : {json}"
        # We need to find the JSON object starting with {
        json_start = line.index("{")
        next unless json_start

        json_portion = line[json_start..]

        begin
          ::JSON.parse(json_portion)
        rescue ::JSON::ParserError
          nil
        end
      end
    end

    # Find log entries matching specific criteria
    # Returns array of matching log entries
    #
    # Example:
    #   find_log_entries(logs, event: "image_downloaded", card_id: "test-123")
    def find_log_entries(log_string, **criteria)
      parsed_logs = parse_json_logs(log_string)

      parsed_logs.select do |entry|
        criteria.all? { |key, value| entry[key.to_s] == value.to_s }
      end
    end

    # Assert that a JSON log entry exists with the given criteria
    #
    # Example:
    #   assert_log_entry(logs, event: "cache_completed", status: "success")
    def assert_log_entry(log_string, **criteria)
      matches = find_log_entries(log_string, **criteria)

      assert matches.any?,
             "Expected to find log entry matching #{criteria.inspect}, " \
             "but found none. Available logs:\n#{format_parsed_logs(log_string)}"
    end

    # Format parsed logs for easier debugging in test failures
    def format_parsed_logs(log_string)
      parsed_logs = parse_json_logs(log_string)

      if parsed_logs.empty?
        "No valid JSON log entries found. Raw logs:\n#{log_string}"
      else
        parsed_logs.map.with_index do |entry, i|
          "  [#{i}] #{entry.inspect}"
        end.join("\n")
      end
    end
  end
end
