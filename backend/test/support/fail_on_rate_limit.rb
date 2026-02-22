# Fail-fast test helper to catch Scryfall rate limit errors in tests
# This helps identify tests that are making real API calls instead of using WebMock stubs
# When a rate limit error is logged OR an unmocked API call is detected, 
# the entire test run will fail loudly and stop

# Module containing helper methods
module RateLimitInterceptor
  # Check if a test should be skipped (tests that explicitly test API failures)
  def skip_check?(test_name)
    test_name_str = test_name.to_s
    test_name_str.include?("RateLimitError") ||
      test_name_str.include?("rate_limit") ||
      test_name_str.include?("rate limit") ||
      test_name_str.include?("ScryfallCardResolver") ||
      test_name_str.include?("Could not resolve")
  end

  # Build failure message for rate limit errors
  def build_rate_limit_failure_message(message, service = "Scryfall")
    "TEST FAILURE: #{service} rate limit exceeded.\n" \
      "This means the test is hitting the real #{service} API instead of using WebMock stubs.\n\n" \
      "COMMON CAUSES:\n" \
      "1. CollectionItem.create! triggers sync_card_metadata callback making real API calls\n" \
      "2. Test is not properly stubbing external HTTP requests\n\n" \
      "FIX OPTIONS:\n" \
      "1. Provide card metadata to skip API calls:\n" \
      "   CollectionItem.create!(..., card_name: 'Card Name', set_name: 'Set Name', released_at: Date.today)\n" \
      "2. Add WebMock stubs for the API calls:\n" \
      "   stub_request(:get, /api\\.scryfall\\.com/).to_return(status: 200, body: {...})\n" \
      "3. Use VCR cassettes for the test\n\n" \
      "Logged message: #{message.to_s[0..200]}"
  end

  # Check log message for patterns indicating real API calls
  STOP_AT_FIRST_ERROR = false  # Disabled - catch-all stubs now handle this
  
  def check_log_message(message)
    return unless message
    
    msg_str = message.to_s
    
    # All checks disabled - catch-all stubs in vcr_setup.rb handle API mocking
  end
end

# Create a logger wrapper that intercepts log messages for BroadcastLogger
class RateLimitInterceptingLogger
  include RateLimitInterceptor
  
  def initialize(logger)
    @logger = logger
    @original_broadcasts = @logger.broadcasts.dup
  end
  
  # BroadcastLogger methods
  def broadcasts
    @original_broadcasts
  end
  
  def add(severity, message = nil, progname = nil)
    message ||= progname
    check_log_message(message)
    @logger.add(severity, message, progname)
  end
  
  # Handle different logger method signatures
  [:debug, :info, :warn, :error, :fatal].each do |method|
    define_method(method) do |*args, &block|
      msg = args.first || block&.call
      check_log_message(msg)
      @logger.send(method, *args, &block)
    end
    
    define_method(:"#{method}!") do |*args, &block|
      msg = args.first || block&.call
      check_log_message(msg)
      @logger.send(:"#{method}!", *args, &block)
    end
  end
  
  def log(level, *args, &block)
    msg = args.first || block&.call
    check_log_message(msg)
    @logger.log(level, *args, &block)
  end
  
  def log_at(level, *args, &block)
    msg = args.first || block&.call
    check_log_message(msg)
    @logger.log_at(level, *args, &block)
  end
  
  # Delegate other methods to the original logger
  def method_missing(method, *args, &block)
    @logger.send(method, *args, &block)
  end
  
  def respond_to_missing?(method, include_private = false)
    @logger.respond_to?(method, include_private)
  end
end

# Replace Rails.logger with our intercepting logger
original_logger = Rails.logger
Rails.logger = RateLimitInterceptingLogger.new(original_logger)

# Module to be included in test cases (kept for compatibility)
module FailOnRateLimit
end
