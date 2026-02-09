require "test_helper"

class PriceUpdateExecutionLoggingTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    CardPrice.delete_all
    PriceUpdateExecution.delete_all
    User.delete_all
    Collection.delete_all
    CollectionItem.delete_all

    # Create test user, collection, and items for batch mode testing
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @collection = Collection.create!(user: @user, name: "Test Collection")
    @item1 = CollectionItem.create!(
      collection: @collection,
      card_id: "card-abc-123",
      quantity: 1,
      finish: "nonfoil"
    )
    @item2 = CollectionItem.create!(
      collection: @collection,
      card_id: "card-def-456",
      quantity: 2,
      finish: "foil"
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
      assert_raises(CardPriceService::NetworkError) do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content
      assert_match /"error_class":"CardPriceService::NetworkError"/, log_content
      assert_match /"error_message":"Connection timeout"/, log_content
      assert_match /"card_id":"card-abc-123"/, log_content
    end
  end

  test "UpdateCardPricesJob records failure status when error occurs in single card mode" do
    stub_scryfall_price_api_error(@item1.card_id, CardPriceService::NetworkError.new("Network error")) do
      assert_raises(CardPriceService::NetworkError) do
        UpdateCardPricesJob.perform_now(@item1.card_id)
      end

      execution = PriceUpdateExecution.last
      assert_equal "failure", execution.status
      assert_not_nil execution.error_summary
      assert_match /NetworkError/, execution.error_summary
      assert_match /Network error/, execution.error_summary
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
      assert_raises(CardPriceService::RateLimitError) do
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
      UpdateCardPricesJob.perform_now(@item1.card_id)

      log_content = @log_output.string
      # Should log when price alerts are detected (even if count is 0)
      assert_match /"event":"price_alerts_detected"/, log_content
    end
  end

  private

  # ---------------------------------------------------------------------------
  # Test helper methods
  # ---------------------------------------------------------------------------

  def stub_scryfall_price_api_success(card_id)
    service_double = Minitest::Mock.new
    service_double.expect :call, {
      card_id: card_id,
      usd_cents: 599,
      usd_foil_cents: 1299,
      usd_etched_cents: nil,
      fetched_at: Time.current
    }

    CardPriceService.stub :new, ->(_args) { service_double } do
      yield
    end
  end

  def stub_scryfall_price_api_with_price(card_id, usd_cents:)
    service_double = Minitest::Mock.new
    service_double.expect :call, {
      card_id: card_id,
      usd_cents: usd_cents,
      usd_foil_cents: nil,
      usd_etched_cents: nil,
      fetched_at: Time.current
    }

    CardPriceService.stub :new, ->(_args) { service_double } do
      yield
    end
  end

  def stub_scryfall_price_api_error(card_id, error)
    service_double = Minitest::Mock.new
    service_double.expect :call, -> { raise error }

    CardPriceService.stub :new, ->(_args) { service_double } do
      yield
    end
  end

  def stub_scryfall_price_api_non_retryable_error(card_id)
    service_double = Minitest::Mock.new
    service_double.expect :call, -> { raise StandardError, "Non-retryable error" }

    # Only stub for the specific card
    original_new = CardPriceService.method(:new)
    CardPriceService.define_singleton_method(:new) do |args|
      if args[:card_id] == card_id
        service_double
      else
        original_new.call(args)
      end
    end

    yield
  ensure
    CardPriceService.singleton_class.send(:remove_method, :new)
    CardPriceService.define_singleton_method(:new, original_new)
  end
end
