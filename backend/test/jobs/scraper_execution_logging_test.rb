require "test_helper"

class ScraperExecutionLoggingTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all
    ScraperExecution.delete_all

    # Clear Scryfall cache to ensure consistent test behavior
    ScryfallCardResolver.clear_cache

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
  # ScrapeEdhrecCommandersJob: Execution record creation
  # ---------------------------------------------------------------------------
  test "ScrapeEdhrecCommandersJob creates execution record with started_at" do
    mock_commanders = build_mock_commanders(5)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      assert_difference "ScraperExecution.count", 1 do
        ScrapeEdhrecCommandersJob.perform_now
      end

      execution = ScraperExecution.last
      assert_not_nil execution.started_at
      assert execution.started_at <= Time.current
    end
  end

  test "ScrapeEdhrecCommandersJob sets finished_at when completed" do
    mock_commanders = build_mock_commanders(3)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      execution = ScraperExecution.last
      assert_not_nil execution.finished_at
      assert execution.finished_at >= execution.started_at
      assert execution.execution_time_seconds.positive?
    end
  end

  test "ScrapeEdhrecCommandersJob records success status when all commanders processed" do
    mock_commanders = build_mock_commanders(5)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      execution = ScraperExecution.last
      assert_equal "success", execution.status
      assert_equal 5, execution.commanders_attempted
      assert_equal 5, execution.commanders_succeeded
      assert_equal 0, execution.commanders_failed
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeEdhrecCommandersJob: Structured JSON logging
  # ---------------------------------------------------------------------------
  test "ScrapeEdhrecCommandersJob logs scrape_started event in JSON format" do
    mock_commanders = build_mock_commanders(2)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      log_content = @log_output.string
      assert_match /"event":"scrape_started"/, log_content
      assert_match /"component":"ScrapeEdhrecCommandersJob"/, log_content
      assert_match /"timestamp":"#{Time.current.year}/, log_content
    end
  end

  test "ScrapeEdhrecCommandersJob logs scrape_completed event with execution summary" do
    mock_commanders = build_mock_commanders(3)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      log_content = @log_output.string
      assert_match /"event":"scrape_completed"/, log_content
      assert_match /"status":"success"/, log_content
      assert_match /"commanders_attempted":3/, log_content
      assert_match /"commanders_succeeded":3/, log_content
      assert_match /"duration_seconds":/, log_content
    end
  end

  test "ScrapeEdhrecCommandersJob logs commander_processed event for each commander" do
    mock_commanders = build_mock_commanders(2)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      log_content = @log_output.string
      assert_match /"event":"commander_processed"/, log_content
      assert_match /"commander_name":"Commander 1"/, log_content
      assert_match /"commander_name":"Commander 2"/, log_content
      assert_match /"rank":1/, log_content
      assert_match /"rank":2/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeEdhrecCommandersJob: Error logging
  # ---------------------------------------------------------------------------
  test "ScrapeEdhrecCommandersJob logs error with full context when EDHREC fetch fails" do
    stub_edhrec_fetch_error(EdhrecScraper::FetchError.new("Connection timeout")) do
      assert_raises(EdhrecScraper::FetchError) do
        ScrapeEdhrecCommandersJob.perform_now
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content
      assert_match /"error_class":"EdhrecScraper::FetchError"/, log_content
      assert_match /"error_message":"Connection timeout"/, log_content
      assert_match /"component":"ScrapeEdhrecCommandersJob"/, log_content
    end
  end

  test "ScrapeEdhrecCommandersJob records failure status when error occurs" do
    stub_edhrec_fetch_error(EdhrecScraper::FetchError.new("Network error")) do
      assert_raises(EdhrecScraper::FetchError) do
        ScrapeEdhrecCommandersJob.perform_now
      end

      execution = ScraperExecution.last
      assert_equal "failure", execution.status
      assert_not_nil execution.error_summary
      assert_match /FetchError/, execution.error_summary
      assert_match /Network error/, execution.error_summary
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeCommanderDecklistJob: Execution tracking
  # ---------------------------------------------------------------------------
  test "ScrapeCommanderDecklistJob increments total_cards_processed counter" do
    commander = Commander.create!(
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test"
    )

    # Create execution record first (simulating parent job)
    execution = ScraperExecution.create!(started_at: Time.current)

    mock_decklist = [
      { name: "Sol Ring", scryfall_id: "abc123", scryfall_uri: "https://scryfall.com/card/sol-ring", is_commander: false },
      { name: "Command Tower", scryfall_id: "def456", scryfall_uri: "https://scryfall.com/card/command-tower", is_commander: false }
    ]

    stub_edhrec_decklist(mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id, execution.id)

      execution.reload
      assert_equal 2, execution.total_cards_processed
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeCommanderDecklistJob: Structured JSON logging
  # ---------------------------------------------------------------------------
  test "ScrapeCommanderDecklistJob logs decklist_scrape_started event" do
    commander = Commander.create!(
      name: "Atraxa",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa"
    )

    mock_decklist = [ { name: "Sol Ring", scryfall_id: "abc", scryfall_uri: "https://scryfall.com", is_commander: false } ]

    stub_edhrec_decklist(mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      log_content = @log_output.string
      assert_match /"event":"decklist_scrape_started"/, log_content
      assert_match /"commander_name":"Atraxa"/, log_content
      assert_match /"commander_id":#{commander.id}/, log_content
      assert_match /"edhrec_url":"https:\/\/edhrec.com\/commanders\/atraxa"/, log_content
    end
  end

  test "ScrapeCommanderDecklistJob logs decklist_scrape_completed event with card count" do
    commander = Commander.create!(
      name: "Test",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test"
    )

    mock_decklist = [
      { name: "Card 1", scryfall_id: "id1", scryfall_uri: "https://scryfall.com/1", is_commander: false },
      { name: "Card 2", scryfall_id: "id2", scryfall_uri: "https://scryfall.com/2", is_commander: false },
      { name: "Card 3", scryfall_id: "id3", scryfall_uri: "https://scryfall.com/3", is_commander: false }
    ]

    stub_edhrec_decklist(mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      log_content = @log_output.string
      assert_match /"event":"decklist_scrape_completed"/, log_content
      assert_match /"cards_count":3/, log_content
      assert_match /"commander_name":"Test"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeCommanderDecklistJob: Error logging
  # ---------------------------------------------------------------------------
  test "ScrapeCommanderDecklistJob logs error with commander context when fetch fails" do
    commander = Commander.create!(
      name: "Error Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/error"
    )

    stub_edhrec_decklist_error(EdhrecScraper::FetchError.new("HTTP 404 Not Found")) do
      assert_raises(EdhrecScraper::FetchError) do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content
      assert_match /"commander_name":"Error Commander"/, log_content
      assert_match /"commander_id":#{commander.id}/, log_content
      assert_match /"edhrec_url":"https:\/\/edhrec.com\/commanders\/error"/, log_content
      assert_match /"error_class":"EdhrecScraper::FetchError"/, log_content
      assert_match /"error_message":"HTTP 404 Not Found"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # Rate limiting logging
  # ---------------------------------------------------------------------------
  test "logs WARN level when rate limit encountered" do
    mock_commanders = build_mock_commanders(1)

    # Simulate rate limit error
    stub_edhrec_rate_limit(retry_after: 60) do
      assert_raises(EdhrecScraper::RateLimitError) do
        ScrapeEdhrecCommandersJob.perform_now
      end

      log_content = @log_output.string
      assert_match /"level":"WARN"/, log_content
      assert_match /"event":"rate_limit_encountered"/, log_content
      assert_match /"service":"EDHREC"/, log_content
      assert_match /"retry_after_seconds":60/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # Sensitive data redaction
  # ---------------------------------------------------------------------------
  test "does not log sensitive credentials in error messages" do
    # Set fake API key environment variable
    original_key = ENV["SCRYFALL_API_KEY"]
    ENV["SCRYFALL_API_KEY"] = "secret_api_key_123"

    mock_commanders = build_mock_commanders(1)

    stub_edhrec_fetch_error(StandardError.new("Error with SCRYFALL_API_KEY=secret_api_key_123")) do
      assert_raises(StandardError) do
        ScrapeEdhrecCommandersJob.perform_now
      end

      log_content = @log_output.string
      assert_no_match /secret_api_key_123/, log_content
      assert_match /\[REDACTED\]/, log_content
    end
  ensure
    ENV["SCRYFALL_API_KEY"] = original_key
  end

  # ---------------------------------------------------------------------------
  # ISO 8601 timestamp format
  # ---------------------------------------------------------------------------
  test "logs timestamps in ISO 8601 format" do
    mock_commanders = build_mock_commanders(1)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      log_content = @log_output.string
      # ISO 8601 format: 2026-02-08T10:30:45Z or 2026-02-08T10:30:45+00:00
      assert_match /"timestamp":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # Log levels
  # ---------------------------------------------------------------------------
  test "uses appropriate log levels for different events" do
    mock_commanders = build_mock_commanders(1)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      log_content = @log_output.string
      # Should have INFO level for normal operations
      assert_match /"level":"INFO"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # Partial success status
  # ---------------------------------------------------------------------------
  test "records partial_success status when some commanders fail" do
    # This test will be implemented when we add individual commander error handling
    # For now, we'll skip it as the current implementation doesn't support partial success
    skip "Partial success tracking will be implemented in future iteration"
  end

  private

  # ---------------------------------------------------------------------------
  # Test helper methods
  # ---------------------------------------------------------------------------

  def stub_edhrec_discovery(top_commanders:)
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { top_commanders }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  def stub_edhrec_decklist(decklist_data)
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |_url| decklist_data }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
  end

  def stub_edhrec_fetch_error(error)
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { raise error }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  def stub_edhrec_decklist_error(error)
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |_url| raise error }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
  end

  def stub_edhrec_rate_limit(retry_after:)
    error = EdhrecScraper::RateLimitError.new("Rate limit exceeded")
    error.define_singleton_method(:retry_after) { retry_after }
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { raise error }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  def build_mock_commanders(count)
    (1..count).map do |i|
      {
        name: "Commander #{i}",
        rank: i,
        url: "https://edhrec.com/commanders/commander-#{i}"
      }
    end
  end
end
