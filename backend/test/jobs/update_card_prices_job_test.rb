require "test_helper"
require "webmock/minitest"

class UpdateCardPricesJobTest < ActiveJob::TestCase
  setup do
    WebMock.reset!
    CardPrice.delete_all
    CollectionItem.delete_all
    User.delete_all
    Rails.cache.clear

    # Create test users for batch processing tests
    @user_one = User.create!(email: "user_one@test.com", name: "Test User One")
    @user_two = User.create!(email: "user_two@test.com", name: "Test User Two")
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

    # Job should raise an error (either RateLimitError or RuntimeError from retry mechanism)
    # when perform_now is used with retry_on declarations
    error_raised = false
    begin
      UpdateCardPricesJob.perform_now(card_id)
    rescue StandardError => e
      error_raised = true
      # Should be either RateLimitError or a RuntimeError about retry delays
      assert e.is_a?(CardPriceService::RateLimitError) || e.message.include?("delay"),
        "Expected RateLimitError or retry-related error, got #{e.class}: #{e.message}"
    end

    assert error_raised, "Expected an error to be raised"

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
      error_raised = false
      begin
        UpdateCardPricesJob.perform_now(card_id)
      rescue StandardError => e
        error_raised = true
        # Should be either NetworkError or a RuntimeError about retry delays
        assert e.is_a?(CardPriceService::NetworkError) || e.message.include?("delay"),
          "Expected NetworkError or retry-related error, got #{e.class}: #{e.message}"
      end
      assert error_raised, "Expected an error to be raised"
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

  test "job creates multiple price records for historical tracking" do
    card_id = "test-uuid-multiple-records"
    stub_scryfall_price_request(card_id, { usd: "10.00" })

    # First call
    UpdateCardPricesJob.perform_now(card_id)
    first_count = CardPrice.where(card_id: card_id).count

    # Immediate second call
    # Note: Test environment uses :null_store for caching, so service will make
    # another API call. This is correct for historical tracking - we want a new
    # price record even if the price hasn't changed.
    UpdateCardPricesJob.perform_now(card_id)
    second_count = CardPrice.where(card_id: card_id).count

    # Both calls should create records for historical tracking
    assert_equal 1, first_count
    assert_equal 2, second_count
  end

  test "job can be enqueued with delay" do
    card_id = "test-uuid-delayed"

    assert_enqueued_with(job: UpdateCardPricesJob, args: [card_id], at: 1.hour.from_now) do
      UpdateCardPricesJob.set(wait: 1.hour).perform_later(card_id)
    end
  end

  test "job validates card_id parameter when provided" do
    # Test that job handles invalid card_id (empty string)
    log_output = capture_log do
      assert_raises(ArgumentError) do
        UpdateCardPricesJob.perform_now("")
      end
    end

    assert_match(/card_id.*required/i, log_output)
  end

  test "job accepts nil to process all cards" do
    # Clear any existing collection items to avoid fixture interference
    CollectionItem.delete_all

    # nil should trigger batch mode, not raise an error
    # With no collection items, should complete with no processing
    assert_nothing_raised do
      UpdateCardPricesJob.perform_now(nil)
    end

    # No prices should be created
    assert_equal 0, CardPrice.count
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

  # ---------------------------------------------------------------------------
  # Batch Processing Tests
  # ---------------------------------------------------------------------------

  test "batch mode processes all unique cards from collection items" do
    card_ids = ["card-1", "card-2", "card-3"]

    # Create collection items with these cards
    card_ids.each do |card_id|
      CollectionItem.create!(
        user: @user_one,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
    end

    # Stub API calls for all cards
    card_ids.each do |card_id|
      stub_scryfall_price_request(card_id, { usd: "10.00" })
    end

    # Run job in batch mode (nil argument)
    assert_difference "CardPrice.count", 3 do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Verify all cards have price records
    card_ids.each do |card_id|
      price_record = CardPrice.latest_for(card_id)
      assert_not_nil price_record, "Expected price record for #{card_id}"
      assert_equal card_id, price_record.card_id
      assert_equal 1000, price_record.usd_cents
    end
  end

  test "batch mode deduplicates cards across inventory and wishlist" do
    user = @user_one
    card_id = "duplicate-card"

    # Add same card to both inventory and wishlist
    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 2
    )

    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "wishlist",
      quantity: 1
    )

    # Stub API call - should only be called once
    stub_scryfall_price_request(card_id, { usd: "15.50" })

    # Run job in batch mode
    assert_difference "CardPrice.count", 1 do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Verify only one price record was created
    assert_equal 1, CardPrice.where(card_id: card_id).count

    price_record = CardPrice.latest_for(card_id)
    assert_equal 1550, price_record.usd_cents
  end

  test "batch mode processes multiple users cards" do
    user1 = @user_one
    user2 = @user_two

    # Each user has different cards
    CollectionItem.create!(
      user: user1,
      card_id: "user1-card",
      collection_type: "inventory",
      quantity: 1
    )

    CollectionItem.create!(
      user: user2,
      card_id: "user2-card",
      collection_type: "inventory",
      quantity: 1
    )

    stub_scryfall_price_request("user1-card", { usd: "5.00" })
    stub_scryfall_price_request("user2-card", { usd: "8.00" })

    # Run job in batch mode
    assert_difference "CardPrice.count", 2 do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Verify both cards have prices
    assert_equal 500, CardPrice.latest_for("user1-card").usd_cents
    assert_equal 800, CardPrice.latest_for("user2-card").usd_cents
  end

  test "batch mode processes cards in batches with delays" do
    user = @user_one

    # Create 55 cards (to ensure multiple batches with BATCH_SIZE = 50)
    card_ids = (1..55).map { |i| "batch-card-#{i}" }

    card_ids.each do |card_id|
      CollectionItem.create!(
        user: user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_price_request(card_id, { usd: "1.00" })
    end

    # Measure execution time to verify delays are being added
    start_time = Time.current

    UpdateCardPricesJob.perform_now(nil)

    execution_time = Time.current - start_time

    # Verify all cards were processed
    assert_equal 55, CardPrice.count

    # With BATCH_SIZE=50 and BATCH_DELAY=0.1, we expect at least 0.1 seconds
    # for the 1 delay between batch 1 (50 cards) and batch 2 (5 cards)
    # Adding some buffer for test execution time
    assert execution_time >= 0.09, "Expected at least 0.09s execution time for batch delays, got #{execution_time}s"
  end

  test "batch mode skips already processed cards for idempotency" do
    user = @user_one
    card_id = "already-processed"

    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Create a price record from today
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 500,
      fetched_at: Time.current
    )

    # Stub should not be called because card already processed
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 500, body: "Should not be called")

    # Run job - should skip already processed card
    assert_no_difference "CardPrice.count" do
      UpdateCardPricesJob.perform_now(nil)
    end
  end

  test "batch mode processes cards with price from yesterday" do
    user = @user_one
    card_id = "yesterday-price"

    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Create a price record from yesterday
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 500,
      fetched_at: 1.day.ago
    )

    # Stub API call - should be called for today's price
    stub_scryfall_price_request(card_id, { usd: "6.00" })

    # Run job - should create new price record for today
    assert_difference "CardPrice.count", 1 do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Verify we have 2 price records now
    assert_equal 2, CardPrice.where(card_id: card_id).count

    # Latest should be today's price
    latest = CardPrice.latest_for(card_id)
    assert_equal 600, latest.usd_cents
  end

  test "batch mode logs progress every 100 cards" do
    user = @user_one

    # Create 250 cards to trigger multiple progress logs
    card_ids = (1..250).map { |i| "progress-card-#{i}" }

    card_ids.each do |card_id|
      CollectionItem.create!(
        user: user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_price_request(card_id, { usd: "1.00" })
    end

    log_output = capture_log do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Should log progress at 100 and 200 cards
    assert_match(/Processed 100 cards/i, log_output)
    assert_match(/Processed 200 cards/i, log_output)
  end

  test "batch mode logs total execution time" do
    user = @user_one

    CollectionItem.create!(
      user: user,
      card_id: "timing-card",
      collection_type: "inventory",
      quantity: 1
    )
    stub_scryfall_price_request("timing-card", { usd: "1.00" })

    log_output = capture_log do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Should log completion time
    assert_match(/Completed price update job in .+ seconds/i, log_output)
    assert_match(/Updated prices for \d+ cards/i, log_output)
  end

  test "batch mode logs starting message with card count" do
    user = @user_one

    CollectionItem.create!(
      user: user,
      card_id: "log-card",
      collection_type: "inventory",
      quantity: 1
    )
    stub_scryfall_price_request("log-card", { usd: "1.00" })

    log_output = capture_log do
      UpdateCardPricesJob.perform_now(nil)
    end

    assert_match(/Starting batch price update for 1 unique cards/i, log_output)
  end

  test "batch mode continues processing after single card error" do
    user = @user_one

    # Create 3 cards, middle one will fail
    CollectionItem.create!(user: user, card_id: "good-card-1", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: user, card_id: "bad-card", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: user, card_id: "good-card-2", collection_type: "inventory", quantity: 1)

    stub_scryfall_price_request("good-card-1", { usd: "1.00" })
    stub_request(:get, "https://api.scryfall.com/cards/bad-card")
      .to_return(status: 500, body: "Internal Server Error")
    stub_scryfall_price_request("good-card-2", { usd: "2.00" })

    log_output = capture_log do
      # Should create 2 records (skip the bad one)
      assert_difference "CardPrice.count", 2 do
        UpdateCardPricesJob.perform_now(nil)
      end
    end

    # Should log error but continue
    assert_match(/Error processing card bad-card/i, log_output)

    # Verify good cards were processed
    assert_not_nil CardPrice.latest_for("good-card-1")
    assert_not_nil CardPrice.latest_for("good-card-2")
    assert_nil CardPrice.latest_for("bad-card")
  end

  test "batch mode with large dataset handles 1000 cards" do
    user = @user_one

    # Create 1000 cards
    card_ids = (1..1000).map { |i| format("large-card-%04d", i) }

    card_ids.each do |card_id|
      CollectionItem.create!(
        user: user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_price_request(card_id, { usd: "1.50" })
    end

    start_time = Time.current

    log_output = capture_log do
      assert_difference "CardPrice.count", 1000 do
        UpdateCardPricesJob.perform_now(nil)
      end
    end

    execution_time = Time.current - start_time

    # Should complete without timeout (less than 60 seconds for test)
    assert execution_time < 60, "Job took too long: #{execution_time} seconds"

    # Should log progress multiple times
    assert_match(/Starting batch price update for 1000 unique cards/i, log_output)
    assert_match(/Processed 100 cards/i, log_output)
    assert_match(/Processed 500 cards/i, log_output)
    assert_match(/Completed price update job/i, log_output)

    # Verify all cards were processed
    assert_equal 1000, CardPrice.count
  end

  test "batch mode reraises rate limit error for job retry" do
    user = @user_one

    CollectionItem.create!(
      user: user,
      card_id: "rate-limit-batch",
      collection_type: "inventory",
      quantity: 1
    )

    stub_request(:get, "https://api.scryfall.com/cards/rate-limit-batch")
      .to_return(status: 429, body: '{"object":"error","code":"rate_limit"}')

    # In test mode, the retry mechanism raises RuntimeError about exponential delay
    # This is expected behavior - we just want to confirm the error propagates
    assert_raises(RuntimeError, CardPriceService::RateLimitError) do
      UpdateCardPricesJob.perform_now(nil)
    end
  end

  test "batch mode reraises network error for job retry" do
    user = @user_one

    CollectionItem.create!(
      user: user,
      card_id: "network-error-batch",
      collection_type: "inventory",
      quantity: 1
    )

    stub_request(:get, "https://api.scryfall.com/cards/network-error-batch")
      .to_raise(SocketError.new("Connection failed")).times(3)

    # In test mode, the retry mechanism raises RuntimeError about exponential delay
    # This is expected behavior - we just want to confirm the error propagates
    assert_raises(RuntimeError, CardPriceService::NetworkError) do
      UpdateCardPricesJob.perform_now(nil)
    end
  end

  test "batch mode resumes from last successful batch after failure" do
    user = @user_one

    # Create 55 cards (batch 1: 50 cards, batch 2: 5 cards)
    card_ids = (1..55).map { |i| "resume-card-#{i}" }

    card_ids.each do |card_id|
      CollectionItem.create!(
        user: user,
        card_id: card_id,
        collection_type: "inventory",
        quantity: 1
      )
      stub_scryfall_price_request(card_id, { usd: "1.00" })
    end

    # First run: process batch 1 successfully
    first_batch_cards = card_ids[0..49]
    first_batch_cards.each do |card_id|
      CardPrice.create!(
        card_id: card_id,
        usd_cents: 100,
        fetched_at: Time.current
      )
    end

    # Second run: should only process remaining 5 cards
    assert_difference "CardPrice.count", 5 do
      UpdateCardPricesJob.perform_now(nil)
    end

    # Verify total is now 55
    assert_equal 55, CardPrice.count
  end

  # ---------------------------------------------------------------------------
  # Price Alert Detection Integration
  # ---------------------------------------------------------------------------

  test "batch mode triggers price alert detection after updating prices" do
    user = @user_one
    card_id = "alert-test-card"

    # Create inventory item
    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    # Create old price (1 day ago)
    CardPrice.create!(
      card_id: card_id,
      usd_cents: 100,
      fetched_at: 1.day.ago
    )

    # Stub new price with 30% increase
    stub_scryfall_price_request(card_id, { usd: "1.30" })

    log_output = capture_log do
      # Should create price record and price alert
      assert_difference "CardPrice.count", 1 do
        assert_difference "PriceAlert.count", 1 do
          UpdateCardPricesJob.perform_now(nil)
        end
      end
    end

    # Should log alert detection
    assert_match(/Detecting price changes for alerts/i, log_output)
    assert_match(/Created 1 price alerts/i, log_output)

    # Verify alert was created correctly
    alert = PriceAlert.last
    assert_equal user, alert.user
    assert_equal card_id, alert.card_id
    assert_equal "price_increase", alert.alert_type
    assert_equal 100, alert.old_price_cents
    assert_equal 130, alert.new_price_cents
  end

  test "batch mode continues even if price alert detection fails" do
    user = @user_one
    card_id = "alert-error-card"

    CollectionItem.create!(
      user: user,
      card_id: card_id,
      collection_type: "inventory",
      quantity: 1
    )

    stub_scryfall_price_request(card_id, { usd: "1.00" })

    # Create a mock service that raises an error
    failing_service = Object.new
    def failing_service.detect_price_changes
      raise StandardError.new("Alert error")
    end

    PriceAlertService.stub(:new, failing_service) do
      log_output = capture_log do
        # Should still create price record even if alert detection fails
        assert_difference "CardPrice.count", 1 do
          assert_no_difference "PriceAlert.count" do
            UpdateCardPricesJob.perform_now(nil)
          end
        end
      end

      # Should log error but not fail the job
      assert_match(/Error detecting price changes/i, log_output)
    end
  end
end
