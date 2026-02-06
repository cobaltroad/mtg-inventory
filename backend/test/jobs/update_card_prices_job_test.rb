require "test_helper"
require "webmock/minitest"

class UpdateCardPricesJobTest < ActiveJob::TestCase
  setup do
    WebMock.reset!
    CardPrice.delete_all
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test background job for updating card prices
  # ---------------------------------------------------------------------------

  test "job can be enqueued" do
    card_id = "test-uuid-enqueue"

    assert_enqueued_with(job: UpdateCardPricesJob, args: [card_id]) do
      UpdateCardPricesJob.perform_later(card_id)
    end
  end

  test "job fetches prices and creates CardPrice record" do
    card_id = "test-uuid-job-success"
    stub_scryfall_price_request(card_id, {
      usd: "10.50",
      usd_foil: "25.00",
      usd_etched: nil
    })

    assert_difference "CardPrice.count", 1 do
      UpdateCardPricesJob.perform_now(card_id)
    end

    price_record = CardPrice.latest_for(card_id)
    assert_not_nil price_record
    assert_equal card_id, price_record.card_id
    assert_equal 1050, price_record.usd_cents
    assert_equal 2500, price_record.usd_foil_cents
    assert_nil price_record.usd_etched_cents
    assert_not_nil price_record.fetched_at
  end

  test "job creates record even when prices are null" do
    card_id = "test-uuid-no-prices"
    stub_scryfall_price_request(card_id, {
      usd: nil,
      usd_foil: nil,
      usd_etched: nil
    })

    assert_difference "CardPrice.count", 1 do
      UpdateCardPricesJob.perform_now(card_id)
    end

    price_record = CardPrice.latest_for(card_id)
    assert_not_nil price_record
    assert_equal card_id, price_record.card_id
    assert_nil price_record.usd_cents
    assert_nil price_record.usd_foil_cents
    assert_nil price_record.usd_etched_cents
  end

  test "job handles rate limit errors with retry" do
    card_id = "test-uuid-rate-limit"

    # Configure job to retry on rate limit
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 429, body: '{"object":"error","code":"rate_limit"}')

    # Job should raise RateLimitError which triggers retry
    assert_raises(CardPriceService::RateLimitError) do
      UpdateCardPricesJob.perform_now(card_id)
    end

    # No record should be created on rate limit
    assert_nil CardPrice.latest_for(card_id)
  end

  test "job handles network errors with retry" do
    card_id = "test-uuid-network-error"

    # First attempt fails, second succeeds
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed"))
      .then.to_return(
        status: 200,
        body: {
          id: card_id,
          prices: { usd: "10.00" }
        }.to_json
      )

    # Should succeed after retry within service
    assert_difference "CardPrice.count", 1 do
      UpdateCardPricesJob.perform_now(card_id)
    end

    price_record = CardPrice.latest_for(card_id)
    assert_equal 1000, price_record.usd_cents
  end

  test "job logs success message" do
    card_id = "test-uuid-log-success"
    stub_scryfall_price_request(card_id, { usd: "10.00" })

    log_output = capture_log do
      UpdateCardPricesJob.perform_now(card_id)
    end

    assert_match(/successfully updated/i, log_output)
    assert_match(/#{card_id}/, log_output)
  end

  test "job logs error message on failure" do
    card_id = "test-uuid-log-error"

    # All attempts fail
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed")).times(3)

    log_output = capture_log do
      assert_raises(CardPriceService::NetworkError) do
        UpdateCardPricesJob.perform_now(card_id)
      end
    end

    assert_match(/failed to update/i, log_output)
    assert_match(/#{card_id}/, log_output)
  end

  test "job handles non-existent card gracefully" do
    card_id = "test-uuid-not-found"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    # Should not create a record for 404 response
    assert_no_difference "CardPrice.count" do
      UpdateCardPricesJob.perform_now(card_id)
    end
  end

  test "job can update prices for same card multiple times" do
    card_id = "test-uuid-multiple-updates"

    # First update
    stub_scryfall_price_request(card_id, { usd: "10.00" })
    UpdateCardPricesJob.perform_now(card_id)

    first_price = CardPrice.latest_for(card_id)
    assert_equal 1000, first_price.usd_cents

    # Wait a moment to ensure different timestamps
    sleep 0.1

    # Second update with different price
    stub_scryfall_price_request(card_id, { usd: "12.00" })
    UpdateCardPricesJob.perform_now(card_id)

    # Should have two records
    assert_equal 2, CardPrice.where(card_id: card_id).count

    # Latest should be the new price
    latest_price = CardPrice.latest_for(card_id)
    assert_equal 1200, latest_price.usd_cents
    assert latest_price.fetched_at > first_price.fetched_at
  end

  test "job is idempotent within cache window" do
    card_id = "test-uuid-idempotent"
    stub = stub_scryfall_price_request(card_id, { usd: "10.00" })

    # First call
    UpdateCardPricesJob.perform_now(card_id)
    first_count = CardPrice.where(card_id: card_id).count

    # Immediate second call should use cache
    UpdateCardPricesJob.perform_now(card_id)
    second_count = CardPrice.where(card_id: card_id).count

    # Both calls should create records, but API called only once due to cache
    assert_equal 2, second_count
    assert_requested stub, times: 1
  end

  test "job can be enqueued with delay" do
    card_id = "test-uuid-delayed"

    assert_enqueued_with(job: UpdateCardPricesJob, args: [card_id], at: 1.hour.from_now) do
      UpdateCardPricesJob.set(wait: 1.hour).perform_later(card_id)
    end
  end

  test "job validates card_id parameter" do
    # Test that job handles missing or invalid card_id
    log_output = capture_log do
      assert_raises(ArgumentError) do
        UpdateCardPricesJob.perform_now(nil)
      end
    end

    assert_match(/card_id.*required/i, log_output)
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
