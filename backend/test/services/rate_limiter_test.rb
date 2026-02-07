require "test_helper"

class RateLimiterTest < ActiveSupport::TestCase
  setup do
    # Clear any previous rate limiter state
    RateLimiter.clear_all_state
  end

  teardown do
    RateLimiter.clear_all_state
  end

  # ---------------------------------------------------------------------------
  # Test: RateLimiter enforces minimum delay between requests
  # ---------------------------------------------------------------------------
  test "enforces minimum delay between consecutive requests" do
    limiter = RateLimiter.new(min_interval_ms: 100, service_name: "test_service")

    start_time = Time.now

    # First request - should not delay
    limiter.throttle

    # Second request - should delay to enforce 100ms interval
    limiter.throttle

    elapsed_ms = (Time.now - start_time) * 1000

    # Should have waited at least 100ms total (allowing small margin for processing time)
    assert elapsed_ms >= 90, "Expected at least 90ms delay, got #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: First request in a series does not delay
  # ---------------------------------------------------------------------------
  test "does not delay first request" do
    limiter = RateLimiter.new(min_interval_ms: 1000, service_name: "test_service")

    start_time = Time.now
    limiter.throttle
    elapsed_ms = (Time.now - start_time) * 1000

    # First request should be immediate (< 50ms for processing overhead)
    assert elapsed_ms < 50, "First request should not delay, but took #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: Multiple rapid requests are properly spaced
  # ---------------------------------------------------------------------------
  test "spaces multiple rapid requests correctly" do
    limiter = RateLimiter.new(min_interval_ms: 50, service_name: "test_service")

    start_time = Time.now

    # Make 4 rapid requests
    4.times { limiter.throttle }

    elapsed_ms = (Time.now - start_time) * 1000

    # 4 requests with 50ms spacing = 150ms total (0ms, 50ms, 100ms, 150ms)
    # Allow 10ms margin for processing overhead
    assert elapsed_ms >= 140, "Expected at least 140ms for 4 requests, got #{elapsed_ms}ms"
    assert elapsed_ms < 200, "Expected less than 200ms for 4 requests, got #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: Different service names maintain independent rate limits
  # ---------------------------------------------------------------------------
  test "maintains independent rate limits for different services" do
    edhrec_limiter = RateLimiter.new(min_interval_ms: 2000, service_name: "edhrec")
    scryfall_limiter = RateLimiter.new(min_interval_ms: 100, service_name: "scryfall")

    # Make request to EDHREC
    edhrec_limiter.throttle

    # Immediately make request to Scryfall - should not be delayed by EDHREC's limit
    start_time = Time.now
    scryfall_limiter.throttle
    elapsed_ms = (Time.now - start_time) * 1000

    # Should be immediate (< 50ms)
    assert elapsed_ms < 50, "Scryfall request should not be delayed by EDHREC limiter, but took #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: Same service name shares rate limit state
  # ---------------------------------------------------------------------------
  test "shares rate limit state for same service name" do
    limiter1 = RateLimiter.new(min_interval_ms: 100, service_name: "shared_service")
    limiter2 = RateLimiter.new(min_interval_ms: 100, service_name: "shared_service")

    # Make request with first limiter
    limiter1.throttle

    # Request with second limiter should respect first limiter's timing
    start_time = Time.now
    limiter2.throttle
    elapsed_ms = (Time.now - start_time) * 1000

    # Should have waited ~100ms
    assert elapsed_ms >= 90, "Second limiter should respect first limiter's timing, waited only #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: No delay if sufficient time has already passed
  # ---------------------------------------------------------------------------
  test "does not delay if sufficient time has elapsed" do
    limiter = RateLimiter.new(min_interval_ms: 100, service_name: "test_service")

    # First request
    limiter.throttle

    # Wait longer than the rate limit
    sleep(0.15) # 150ms

    # Second request should not delay
    start_time = Time.now
    limiter.throttle
    elapsed_ms = (Time.now - start_time) * 1000

    # Should be immediate since we already waited 150ms
    assert elapsed_ms < 50, "Should not delay when sufficient time has passed, but took #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: EDHREC rate limiter uses 2000ms interval
  # ---------------------------------------------------------------------------
  test "creates EDHREC rate limiter with 2000ms interval" do
    limiter = RateLimiter.for_edhrec

    assert_equal 2000, limiter.min_interval_ms
    assert_equal "edhrec", limiter.service_name
  end

  # ---------------------------------------------------------------------------
  # Test: Scryfall rate limiter uses 100ms interval
  # ---------------------------------------------------------------------------
  test "creates Scryfall rate limiter with 100ms interval" do
    limiter = RateLimiter.for_scryfall

    assert_equal 100, limiter.min_interval_ms
    assert_equal "scryfall", limiter.service_name
  end

  # ---------------------------------------------------------------------------
  # Test: RateLimiter can be cleared for testing
  # ---------------------------------------------------------------------------
  test "clears all rate limiter state" do
    limiter = RateLimiter.new(min_interval_ms: 1000, service_name: "test_service")

    # Make a request to establish timing
    limiter.throttle

    # Clear state
    RateLimiter.clear_all_state

    # Next request should not delay (state was cleared)
    start_time = Time.now
    limiter.throttle
    elapsed_ms = (Time.now - start_time) * 1000

    assert elapsed_ms < 50, "Should not delay after clearing state, but took #{elapsed_ms}ms"
  end

  # ---------------------------------------------------------------------------
  # Test: RateLimiter records last request time
  # ---------------------------------------------------------------------------
  test "records last request time for service" do
    limiter = RateLimiter.new(min_interval_ms: 100, service_name: "test_service")

    before_request = Time.now
    limiter.throttle
    after_request = Time.now

    last_time = RateLimiter.last_request_time_for("test_service")

    assert_not_nil last_time
    assert last_time >= before_request
    assert last_time <= after_request
  end
end
