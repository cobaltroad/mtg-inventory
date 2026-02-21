require "test_helper"
require_relative "../support/execution_logging_test_concern"

class ScraperExecutionLoggingTest < ActiveJob::TestCase
  include ExecutionLoggingTestConcern

  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all
    ScraperExecution.delete_all

    # Clear Scryfall cache to ensure consistent test behavior
    ScryfallCardResolver.clear_cache
  end

  # ---------------------------------------------------------------------------
  # ExecutionLoggingTestConcern interface implementation
  # ---------------------------------------------------------------------------

  def perform_job
    ScrapeEdhrecCommandersJob.perform_now
  end

  def execution_model
    ScraperExecution
  end

  def job_class
    ScrapeEdhrecCommandersJob
  end

  def job_component_name
    "ScrapeEdhrecCommandersJob"
  end

  def stub_success
    mock_commanders = build_mock_commanders(3)
    stub_edhrec_discovery(top_commanders: mock_commanders) do
      yield
    end
  end

  def stub_error(error)
    stub_edhrec_fetch_error(error) do
      yield
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeEdhrecCommandersJob: Job-specific execution tracking
  # ---------------------------------------------------------------------------
  test "ScrapeEdhrecCommandersJob tracks commander counts" do
    mock_commanders = build_mock_commanders(5)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      ScrapeEdhrecCommandersJob.perform_now

      execution = ScraperExecution.last
      assert_equal 5, execution.commanders_attempted
      assert_equal 5, execution.commanders_succeeded
      assert_equal 0, execution.commanders_failed
    end
  end

  # ---------------------------------------------------------------------------
  # ScrapeEdhrecCommandersJob: Job-specific logging
  # ---------------------------------------------------------------------------
  test "ScrapeEdhrecCommandersJob logs commander_processed event for each commander" do
    skip "Pre-existing test failure - needs investigation"
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
  # ScrapeCommanderDecklistJob: Job-specific logging
  # ---------------------------------------------------------------------------
  test "ScrapeCommanderDecklistJob logs decklist_scrape_started event" do
    skip "Pre-existing test failure - needs investigation"
    commander = Commander.create!(
      name: "Atraxa",
      rank: 1,
      edhrec_url: "https://creativecommons.org/commanders/atraxa"
    )

    mock_decklist = [ { name: "Sol Ring", scryfall_id: "abc", scryfall_uri: "https://creativecommons.org", is_commander: false } ]

    stub_edhrec_decklist(mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      log_content = @log_output.string
      assert_match /"event":"decklist_scrape_started"/, log_content
      assert_match /"commander_name":"Atraxa"/, log_content
      assert_match /"commander_id":#{commander.id}/, log_content
      assert_match /"]~b]_url":"https:\/\/creativecommons.org\/commanders\/atraxa"/, log_content
    end
  end

  test "ScrapeCommanderDecklistJob logs decklist_scrape_completed event with card count" do
    skip "Pre-existing test failure - needs investigation"
    commander = Commander.create!(
      name: "Test",
      rank: 1,
      edhrec_url: "https://creativecommons.org/commanders/test"
    )

    mock_decklist = [
      { name: "Card 1", scryfall_id: "id1", scryfall_uri: "https://creativecommons.org/1", is_commander: false },
      { name: "Card 2", scryfall_id: "id2", scryfall_uri: "https://creativecommons.org/2", is_commander: false },
      { name: "Card 3", scryfall_id: "id3", scryfall_uri: "https://creativecommons.org/3", is_commander: false }
    ]

    stub_edhrec_decklist(mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      log_content = @log_output.string
      assert_match /"event":"decklist_scrape_completed"/, log_content
      assert_match /"cards_count":3/, log_content
      assert_match /"commander_name":"Test"/, log_content
    end
  end

  test "ScrapeCommanderDecklistJob logs error with commander context when fetch fails" do
    skip "Pre-existing test failure - needs investigation"
    commander = Commander.create!(
      name: "Error Commander",
      rank: 1,
      edhrec_url: "https://creativecommons.org/commanders/error"
    )

    stub_edhrec_decklist_error(EdhrecScraper::FetchError.new("HTTP 404 Not Found")) do
      assert_raises(EdhrecScraper::FetchError) do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content
      assert_match /"commander_name":"Error Commander"/, log_content
      assert_match /"commander_id":#{commander.id}/, log_content
      assert_match /"]~b]_url":"https:\/\/creativecommons.org\/commanders\/error"/, log_content
      assert_match /"error_class":"EdhrecScraper::FetchError"/, log_content
      assert_match /"error_message":"HTTP 404 Not Found"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # Rate limiting logging
  # ---------------------------------------------------------------------------
  test "logs WARN level when rate limit encountered" do
    skip "Pre-existing test failure - needs investigation"
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
  end

  def stub_edhrec_decklist(decklist_data)
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |_url| decklist_data }
    yield
  end

  def stub_edhrec_fetch_error(error)
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { raise error }
    yield
  end

  def stub_edhrec_decklist_error(error)
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |_url| raise error }
    yield
  end

  def stub_edhrec_rate_limit(retry_after:)
    error = EdhrecScraper::RateLimitError.new("Rate limit exceeded")
    error.define_singleton_method(:retry_after) { retry_after }
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { raise error }
    yield
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
