require "test_helper"
require "webmock/minitest"

class CardPriceServiceTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    # Use memory store for cache testing
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    # Restore original cache
    Rails.cache = @original_cache
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test fetching and parsing card prices from Scryfall API
  # ---------------------------------------------------------------------------

  test "fetches card prices from Scryfall API and converts to cents" do
    card_id = "test-uuid-with-prices"
    stub_scryfall_price_request(card_id, {
      usd: "10.50",
      usd_foil: "25.00",
      usd_etched: "30.75"
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:card_id]
    assert_equal 1050, result[:usd_cents]
    assert_equal 2500, result[:usd_foil_cents]
    assert_equal 3075, result[:usd_etched_cents]
    assert_instance_of Time, result[:fetched_at]
  end

  test "handles cards with only some prices available" do
    card_id = "test-uuid-partial-prices"
    stub_scryfall_price_request(card_id, {
      usd: "5.25",
      usd_foil: nil,
      usd_etched: nil
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal 525, result[:usd_cents]
    assert_nil result[:usd_foil_cents]
    assert_nil result[:usd_etched_cents]
  end

  test "handles cards with no prices available" do
    card_id = "test-uuid-no-prices"
    stub_scryfall_price_request(card_id, {
      usd: nil,
      usd_foil: nil,
      usd_etched: nil
    })

    log_output = capture_log do
      service = CardPriceService.new(card_id: card_id)
      result = service.call

      assert_nil result[:usd_cents]
      assert_nil result[:usd_foil_cents]
      assert_nil result[:usd_etched_cents]
      assert_not_nil result[:fetched_at]
    end

    assert_match(/no price data available/i, log_output)
    assert_match(/test-uuid-no-prices/, log_output)
  end

  test "handles foil-only cards" do
    card_id = "test-uuid-foil-only"
    stub_scryfall_price_request(card_id, {
      usd: nil,
      usd_foil: "15.99",
      usd_etched: nil
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_nil result[:usd_cents]
    assert_equal 1599, result[:usd_foil_cents]
    assert_nil result[:usd_etched_cents]
  end

  test "converts decimal prices to cents correctly" do
    card_id = "test-uuid-decimal-conversion"
    stub_scryfall_price_request(card_id, {
      usd: "0.99",
      usd_foil: "100.01",
      usd_etched: "50.50"
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal 99, result[:usd_cents]
    assert_equal 10001, result[:usd_foil_cents]
    assert_equal 5050, result[:usd_etched_cents]
  end

  # ---------------------------------------------------------------------------
  # Test 24-hour caching behavior
  # ---------------------------------------------------------------------------

  test "caches price data for 24 hours" do
    card_id = "test-uuid-cached"
    stub = stub_scryfall_price_request(card_id, { usd: "10.00" })

    # First call hits API
    service1 = CardPriceService.new(card_id: card_id)
    result1 = service1.call
    assert_equal 1000, result1[:usd_cents]

    # Verify cached
    cached_result = Rails.cache.read("card_price:#{card_id}")
    assert_not_nil cached_result
    assert_equal 1000, cached_result[:usd_cents]

    # Second call uses cache
    service2 = CardPriceService.new(card_id: card_id)
    result2 = service2.call
    assert_equal 1000, result2[:usd_cents]

    # API called only once
    assert_requested stub, times: 1
  end

  test "fetches fresh data after cache expires" do
    card_id = "test-uuid-cache-expiry"
    stub = stub_scryfall_price_request(card_id, { usd: "10.00" })

    # First call
    service1 = CardPriceService.new(card_id: card_id)
    service1.call

    # Clear cache to simulate expiration
    Rails.cache.clear

    # Second call should hit API again
    service2 = CardPriceService.new(card_id: card_id)
    service2.call

    # API called twice
    assert_requested stub, times: 2
  end

  # ---------------------------------------------------------------------------
  # Test rate limiting with exponential backoff
  # ---------------------------------------------------------------------------

  test "raises RateLimitError when Scryfall returns 429" do
    card_id = "test-uuid-rate-limit"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 429, body: '{"object":"error","code":"rate_limit"}')

    log_output = capture_log do
      service = CardPriceService.new(card_id: card_id)

      error = assert_raises(CardPriceService::RateLimitError) do
        service.call
      end

      assert_match(/rate limit/i, error.message)
    end

    assert_match(/rate limit/i, log_output)
  end

  test "retries with exponential backoff on rate limit" do
    card_id = "test-uuid-rate-limit-retry"

    # First request: rate limited
    # Second request: rate limited
    # Third request: succeeds
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 429, body: '{"object":"error","code":"rate_limit"}')
      .then.to_return(status: 429, body: '{"object":"error","code":"rate_limit"}')
      .then.to_return(
        status: 200,
        body: {
          id: card_id,
          prices: { usd: "10.00" }
        }.to_json
      )

    service = CardPriceService.new(card_id: card_id)

    # Mock sleep to avoid actual delays in tests
    sleep_calls = []
    service.stub(:sleep, ->(duration) { sleep_calls << duration }) do
      result = service.call
      assert_equal 1000, result[:usd_cents]
    end

    # Verify exponential backoff: first wait ~1s, second wait ~2s
    assert_equal 2, sleep_calls.length
    assert sleep_calls[0] < sleep_calls[1], "Should use exponential backoff"
  end

  # ---------------------------------------------------------------------------
  # Test network errors with retry logic
  # ---------------------------------------------------------------------------

  test "raises NetworkError on connection failure" do
    card_id = "test-uuid-network-error"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed"))

    log_output = capture_log do
      service = CardPriceService.new(card_id: card_id)

      error = assert_raises(CardPriceService::NetworkError) do
        service.call
      end

      assert_match(/network error/i, error.message)
    end

    assert_match(/network error/i, log_output)
  end

  test "retries up to 3 times on network errors" do
    card_id = "test-uuid-retry"

    # First two requests fail, third succeeds
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed"))
      .then.to_raise(SocketError.new("Connection failed"))
      .then.to_return(
        status: 200,
        body: {
          id: card_id,
          prices: { usd: "10.00" }
        }.to_json
      )

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal 1000, result[:usd_cents]
  end

  test "raises NetworkError after 3 failed retry attempts" do
    card_id = "test-uuid-retry-exhausted"

    # All requests fail
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed")).times(3)

    log_output = capture_log do
      service = CardPriceService.new(card_id: card_id)

      error = assert_raises(CardPriceService::NetworkError) do
        service.call
      end

      assert_match(/connection failed/i, error.message)
    end

    # Should log critical error after final failure
    assert_match(/critical/i, log_output)
  end

  test "raises TimeoutError on request timeout" do
    card_id = "test-uuid-timeout"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_timeout

    service = CardPriceService.new(card_id: card_id)

    assert_raises(CardPriceService::TimeoutError) do
      service.call
    end
  end

  test "handles invalid JSON response" do
    card_id = "test-uuid-invalid-json"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 200, body: "not valid json")

    service = CardPriceService.new(card_id: card_id)

    assert_raises(CardPriceService::InvalidResponseError) do
      service.call
    end
  end

  test "returns nil for non-existent card (404)" do
    card_id = "test-uuid-not-found"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_nil result
  end

  # ---------------------------------------------------------------------------
  # Test price parsing edge cases
  # ---------------------------------------------------------------------------

  test "handles zero-priced cards" do
    card_id = "test-uuid-zero-price"
    stub_scryfall_price_request(card_id, {
      usd: "0.00",
      usd_foil: "0.00",
      usd_etched: nil
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal 0, result[:usd_cents]
    assert_equal 0, result[:usd_foil_cents]
    assert_nil result[:usd_etched_cents]
  end

  test "handles very expensive cards" do
    card_id = "test-uuid-expensive"
    stub_scryfall_price_request(card_id, {
      usd: "10000.00",
      usd_foil: "25000.50",
      usd_etched: nil
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    assert_equal 1000000, result[:usd_cents]
    assert_equal 2500050, result[:usd_foil_cents]
  end

  test "handles prices with many decimal places by rounding" do
    card_id = "test-uuid-many-decimals"
    stub_scryfall_price_request(card_id, {
      usd: "1.999",
      usd_foil: "2.995",
      usd_etched: nil
    })

    service = CardPriceService.new(card_id: card_id)
    result = service.call

    # Should round to nearest cent
    assert_equal 200, result[:usd_cents]
    assert_equal 300, result[:usd_foil_cents]
  end

  private

  def stub_scryfall_price_request(card_id, prices)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Test Card",
          prices: {
            usd: prices[:usd],
            usd_foil: prices[:usd_foil],
            usd_etched: prices[:usd_etched]
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  def capture_log
    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    yield

    Rails.logger = old_logger
    log_output.string
  end
end
