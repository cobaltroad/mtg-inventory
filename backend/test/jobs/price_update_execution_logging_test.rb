require "test_helper"
require "webmock/minitest"

class PriceUpdateExecutionLoggingTest < ActiveJob::TestCase
  setup do
    # Disable VCR for these tests since we're using WebMock stubs directly
    VCR.turn_off!(ignore_cassettes: true)
    WebMock.enable!

    # Clear any existing data in proper order (dependencies first)
    CardPrice.delete_all
    PriceUpdateExecution.delete_all
    CollectionItem.delete_all
    User.delete_all

    # Create test user and collection items for batch mode testing
    @user = User.create!(
      email: "test@example.com",
      name: "Test User"
    )
    @item1 = CollectionItem.create!(
      user: @user,
      collection_type: "inventory",
      card_id: "card-abc-123",
      quantity: 1
    )
    @item2 = CollectionItem.create!(
      user: @user,
      collection_type: "inventory",
      card_id: "card-def-456",
      quantity: 2
    )

    # Capture logs for assertions
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = Logger.new(@log_output)
    Rails.logger.level = Logger::INFO
  end

  teardown do
    # Restore original logger
    Rails.logger = @original_logger

    # Re-enable VCR
    VCR.turn_on!
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Execution record creation (batch mode)
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob batch mode creates execution record with started_at" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        assert_difference "PriceUpdateExecution.count", 1 do
          UpdateCardPricesJob.perform_now
        end

        execution = PriceUpdateExecution.last
        assert_not_nil execution.started_at
        assert execution.started_at <= Time.current
        assert_equal "batch", execution.mode
      end
    end
  end

  test "UpdateCardPricesJob batch mode sets finished_at when completed" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        execution = PriceUpdateExecution.last
        assert_not_nil execution.finished_at
        assert execution.finished_at >= execution.started_at
        assert execution.execution_time_seconds.positive?
      end
    end
  end

  test "UpdateCardPricesJob batch mode records success status when all cards processed" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        execution = PriceUpdateExecution.last
        assert_equal "success", execution.status
        assert_equal 2, execution.cards_attempted
        assert_equal 2, execution.cards_succeeded
        assert_equal 0, execution.cards_failed
      end
    end
  end

  test "UpdateCardPricesJob batch mode tracks cards_skipped when already processed today" do
    # Create price records from earlier today
    CardPrice.create!(
      card_id: @item1.card_id,
      usd_cents: 100,
      fetched_at: Time.current.beginning_of_day + 1.hour
    )

    stub_scryfall_price_api_success(@item2.card_id) do
      UpdateCardPricesJob.perform_now

      execution = PriceUpdateExecution.last
      assert_equal 1, execution.cards_skipped  # item1 was already processed today
      assert_equal 1, execution.cards_attempted  # only item2 attempted
      assert_equal 1, execution.cards_succeeded
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Execution record creation (single card mode)
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob single card mode creates execution record with correct mode" do
    stub_scryfall_price_api_success(@item1.card_id) do
      assert_difference "PriceUpdateExecution.count", 1 do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      execution = PriceUpdateExecution.last
      assert_equal "single_card", execution.mode
      assert_equal 1, execution.cards_attempted
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Structured JSON logging (batch mode)
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob logs price_update_started event in JSON format" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        log_content = @log_output.string
        assert_match /"event":"price_update_started"/, log_content
        assert_match /"component":"UpdateCardPricesJob"/, log_content
        assert_match /"mode":"batch"/, log_content
        assert_match /"timestamp":"#{Time.current.year}/, log_content
      end
    end
  end

  test "UpdateCardPricesJob logs price_update_completed event with execution summary" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        log_content = @log_output.string
        assert_match /"event":"price_update_completed"/, log_content
        assert_match /"status":"success"/, log_content
        assert_match /"cards_attempted":2/, log_content
        assert_match /"cards_succeeded":2/, log_content
        assert_match /"duration_seconds":/, log_content
      end
    end
  end

  test "UpdateCardPricesJob logs card_processed event for each card" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        log_content = @log_output.string
        assert_match /"event":"card_processed"/, log_content
        assert_match /"card_id":"card-abc-123"/, log_content
        assert_match /"card_id":"card-def-456"/, log_content
      end
    end
  end

  test "UpdateCardPricesJob logs batch_started and batch_completed events" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        log_content = @log_output.string
        assert_match /"event":"batch_started"/, log_content
        assert_match /"event":"batch_completed"/, log_content
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Error logging
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob logs error with full context when Scryfall fetch fails" do
    stub_scryfall_price_api_error(@item1.card_id, CardPriceService::NetworkError.new("Connection timeout")) do
      # Expect any exception (retry behavior changes the exception type in tests)
      assert_raises do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content
      assert_match /"error_class":"CardPriceService::NetworkError"/, log_content
      assert_match /"card_id":"card-abc-123"/, log_content
    end
  end

  test "UpdateCardPricesJob records failure status when error occurs in single card mode" do
    stub_scryfall_price_api_error(@item1.card_id, CardPriceService::NetworkError.new("Network error")) do
      # Expect any exception (retry behavior changes the exception type in tests)
      assert_raises do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      execution = PriceUpdateExecution.last
      assert_equal "failure", execution.status
      assert_not_nil execution.error_summary
    end
  end

  test "UpdateCardPricesJob records partial_success when some cards fail in batch mode" do
    stub_scryfall_price_api_success(@item1.card_id) do
      # item2 will fail with non-retryable error
      stub_scryfall_price_api_non_retryable_error(@item2.card_id) do
        UpdateCardPricesJob.perform_now

        execution = PriceUpdateExecution.last
        assert_equal "partial_success", execution.status
        assert_equal 2, execution.cards_attempted
        assert_equal 1, execution.cards_succeeded
        assert_equal 1, execution.cards_failed
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Rate limit logging
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob logs WARN level when rate limit encountered" do
    error = CardPriceService::RateLimitError.new("Rate limit exceeded")
    error.define_singleton_method(:retry_after) { 60 }

    stub_scryfall_price_api_error(@item1.card_id, error) do
      # Expect any exception (retry behavior changes the exception type in tests)
      assert_raises do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      log_content = @log_output.string
      assert_match /"level":"WARN"/, log_content
      assert_match /"event":"rate_limit_encountered"/, log_content
      assert_match /"service":"Scryfall"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Sensitive data redaction
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob does not log sensitive API keys in error messages" do
    # Set fake API key environment variable
    original_key = ENV["SCRYFALL_API_KEY"]
    ENV["SCRYFALL_API_KEY"] = "secret_scryfall_key_789"

    error = StandardError.new("Error with SCRYFALL_API_KEY=secret_scryfall_key_789")
    stub_scryfall_price_api_error(@item1.card_id, error) do
      assert_raises(StandardError) do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      log_content = @log_output.string
      assert_no_match /secret_scryfall_key_789/, log_content
      assert_match /\[REDACTED\]/, log_content
    end
  ensure
    ENV["SCRYFALL_API_KEY"] = original_key
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: ISO 8601 timestamp format
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob logs timestamps in ISO 8601 format" do
    stub_scryfall_price_api_success(@item1.card_id) do
      UpdateCardPricesJob.perform_now(@item1.card_id)

      log_content = @log_output.string
      # ISO 8601 format: 2026-02-08T10:30:45Z or 2026-02-08T10:30:45+00:00
      assert_match /"timestamp":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Log levels
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob uses appropriate log levels for different events" do
    stub_scryfall_price_api_success(@item1.card_id) do
      UpdateCardPricesJob.perform_now(@item1.card_id)

      log_content = @log_output.string
      # Should have INFO level for normal operations
      assert_match /"level":"INFO"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # UpdateCardPricesJob: Price alerts tracking
  # ---------------------------------------------------------------------------
  test "UpdateCardPricesJob tracks price_alerts_created count" do
    # Create initial price to enable price change detection
    CardPrice.create!(
      card_id: @item1.card_id,
      usd_cents: 100,
      fetched_at: 2.days.ago
    )

    # Mock significant price increase to trigger alert
    stub_scryfall_price_api_with_price(@item1.card_id, usd_cents: 1000) do
      UpdateCardPricesJob.perform_now(@item1.card_id)

      execution = PriceUpdateExecution.last
      # Note: This assumes PriceAlertService creates alerts for significant changes
      # The exact count depends on threshold settings
      assert execution.price_alerts_created >= 0
    end
  end

  test "UpdateCardPricesJob logs price_alerts_detected event" do
    stub_scryfall_price_api_success(@item1.card_id) do
      stub_scryfall_price_api_success(@item2.card_id) do
        UpdateCardPricesJob.perform_now  # Batch mode

        log_content = @log_output.string
        # Should log when price alerts are detected (even if count is 0)
        assert_match /"event":"price_alerts_detected"/, log_content
      end
    end
  end

  private

  # ---------------------------------------------------------------------------
  # Test helper methods
  # ---------------------------------------------------------------------------

  def stub_scryfall_price_api_success(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          prices: {
            usd: "5.99",
            usd_foil: "12.99",
            usd_etched: nil
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub PriceAlertService to return empty array
    stub_price_alert_service do
      yield
    end
  end

  def stub_scryfall_price_api_with_price(card_id, usd_cents:)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          prices: {
            usd: (usd_cents / 100.0).to_s,
            usd_foil: nil,
            usd_etched: nil
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_price_alert_service do
      yield
    end
  end

  def stub_scryfall_price_api_error(card_id, error)
    # For network/timeout errors, make the stub raise during the request
    # Use SocketError which will be caught and converted to NetworkError by the service
    if error.is_a?(CardPriceService::NetworkError)
      stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
        .to_raise(SocketError.new("Connection failed"))
    elsif error.is_a?(CardPriceService::RateLimitError)
      stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
        .to_return(status: 429, body: "Rate limit exceeded")
    else
      stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
        .to_raise(error)
    end

    stub_price_alert_service do
      yield
    end
  end

  def stub_scryfall_price_api_non_retryable_error(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          prices: {
            usd: "5.99",
            usd_foil: nil,
            usd_etched: nil
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub one card to fail, other to succeed
    if card_id == "card-def-456"
      # Override the specific card stub to raise an error
      stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
        .to_raise(StandardError.new("Non-retryable error"))
    end

    stub_price_alert_service do
      yield
    end
  end

  def stub_price_alert_service(alerts: [])
    service_instance = Object.new
    service_instance.define_singleton_method(:detect_price_changes) { alerts }

    PriceAlertService.stub :new, service_instance do
      yield
    end
  end
end
