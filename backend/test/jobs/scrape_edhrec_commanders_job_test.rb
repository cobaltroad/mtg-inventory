require "test_helper"

class ScrapeEdhrecCommandersJobTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all

    # Clear Scryfall cache to ensure consistent test behavior
    ScryfallCardResolver.clear_cache
  end

  # ---------------------------------------------------------------------------
  # Test: Job enqueues successfully
  # ---------------------------------------------------------------------------
  test "job enqueues successfully" do
    assert_enqueued_with(job: ScrapeEdhrecCommandersJob) do
      ScrapeEdhrecCommandersJob.perform_later
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job creates all 20 commanders without decklists
  # ---------------------------------------------------------------------------
  test "discovers all 20 commanders and schedules decklist jobs" do
    # Mock the external services
    mock_commanders = build_mock_commanders(20)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      # Execute the job
      assert_enqueued_jobs 20, only: ScrapeCommanderDecklistJob do
        ScrapeEdhrecCommandersJob.perform_now
      end

      # Verify all 20 commanders were created
      assert_equal 20, Commander.count

      # Verify NO decklists were created (discovery only)
      assert_equal 0, Decklist.count

      # Verify first commander has expected attributes
      first_commander = Commander.find_by(name: "Commander 1")
      assert_not_nil first_commander
      assert_equal 1, first_commander.rank
      assert_equal "https://edhrec.com/commanders/commander-1", first_commander.edhrec_url

      # Verify last_scraped_at is nil (not set during discovery)
      assert_nil first_commander.last_scraped_at
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Upsert logic updates existing commanders instead of creating duplicates
  # ---------------------------------------------------------------------------
  test "upserts existing commanders instead of creating duplicates" do
    # Create an existing commander
    existing_commander = Commander.create!(
      name: "Commander 1",
      rank: 5,
      edhrec_url: "https://edhrec.com/commanders/old-url",
      last_scraped_at: 1.day.ago
    )
    original_created_at = existing_commander.created_at
    original_scraped_at = existing_commander.last_scraped_at

    # Mock the scraper to return the same commander with updated data
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      # Execute the job
      ScrapeEdhrecCommandersJob.perform_now

      # Verify only 1 commander exists (not 2)
      assert_equal 1, Commander.count

      # Verify commander was updated, not duplicated
      existing_commander.reload
      assert_equal 1, existing_commander.rank
      assert_equal "https://edhrec.com/commanders/commander-1", existing_commander.edhrec_url

      # Verify last_scraped_at was NOT changed (discovery doesn't scrape decklists)
      assert_equal original_scraped_at.to_i, existing_commander.last_scraped_at.to_i

      # Verify created_at timestamp was preserved
      assert_equal original_created_at.to_i, existing_commander.created_at.to_i
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job does not modify existing decklists
  # ---------------------------------------------------------------------------
  test "discovery job preserves existing decklists" do
    # Create existing commander with decklist
    commander = Commander.create!(
      name: "Commander 1",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/commander-1",
      last_scraped_at: 1.day.ago
    )

    old_decklist = Decklist.create!(
      commander: commander,
      contents: [
        { card_id: "old-id-1", card_name: "Old Card 1", quantity: 1 },
        { card_id: "old-id-2", card_name: "Old Card 2", quantity: 1 }
      ]
    )

    # Mock new discovery data
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      # Execute the job (discovery only)
      ScrapeEdhrecCommandersJob.perform_now

      # Verify decklist was NOT modified
      assert_equal 1, Decklist.count

      # Verify contents were NOT changed (discovery doesn't touch decklists)
      old_decklist.reload
      assert_equal 2, old_decklist.contents.length
      assert old_decklist.contents.any? { |c| c["card_name"] == "Old Card 1" }
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job creates all commanders even if one would fail decklist fetch
  # Note: Discovery doesn't fetch decklists, so all commanders should be created
  # ---------------------------------------------------------------------------
  test "discovery job creates all commanders successfully" do
    # Mock 3 commanders
    mock_commanders = build_mock_commanders(3)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      # Execute the job - should not raise error
      assert_nothing_raised do
        ScrapeEdhrecCommandersJob.perform_now
      end

      # Verify all 3 commanders were created (discovery doesn't fail on individual commanders)
      assert_equal 3, Commander.count
      assert_not_nil Commander.find_by(name: "Commander 1")
      assert_not_nil Commander.find_by(name: "Commander 2")
      assert_not_nil Commander.find_by(name: "Commander 3")

      # Verify no decklists were created (discovery only)
      assert_equal 0, Decklist.count
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Fatal error handling (database down, etc.)
  # ---------------------------------------------------------------------------
  test "raises fatal errors to Solid Queue for retry logic" do
    mock_commanders = build_mock_commanders(1)

    # Stub to raise fatal error during commander creation
    find_or_init_stub = proc do |*args|
      raise ActiveRecord::ConnectionNotEstablished, "Database unavailable"
    end

    # Stub EdhrecScraper and Commander methods
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { mock_commanders }
    Commander.define_singleton_method(:find_or_initialize_by) { |*args| find_or_init_stub.call(*args) }

    begin
      # Verify the fatal error is raised, not caught
      assert_raises ActiveRecord::ConnectionNotEstablished do
        ScrapeEdhrecCommandersJob.perform_now
      end
    ensure
      # Restore original methods
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
      Commander.singleton_class.send(:remove_method, :find_or_initialize_by)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Rate limit errors are re-raised for Solid Queue retry
  # ---------------------------------------------------------------------------
  test "raises rate limit errors for Solid Queue retry" do
    # Stub to raise rate limit error
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) do
      raise EdhrecScraper::RateLimitError, "Rate limit exceeded"
    end

    begin
      # Verify the error is raised, not caught
      assert_raises EdhrecScraper::RateLimitError do
        ScrapeEdhrecCommandersJob.perform_now
      end

      # Verify no commanders were created
      assert_equal 0, Commander.count
    ensure
      # Restore original method
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Summary logging includes all required metrics
  # ---------------------------------------------------------------------------
  test "logs comprehensive summary after discovery" do
    mock_commanders = build_mock_commanders(20)

    # Capture log output
    log_output = []
    original_logger = Rails.logger

    # Create a simple logger that captures messages
    logger = Logger.new(nil)
    logger.define_singleton_method(:info) { |message| log_output << message }
    logger.define_singleton_method(:warn) { |message| log_output << message }
    logger.define_singleton_method(:error) { |message| log_output << message }
    logger.define_singleton_method(:debug) { |message| log_output << message }

    # Stub Rails.logger
    Rails.define_singleton_method(:logger) { logger }

    begin
      stub_edhrec_discovery(top_commanders: mock_commanders) do
        ScrapeEdhrecCommandersJob.perform_now

        # Verify summary log contains completion message
        completion_log = log_output.find { |msg| msg.include?("DISCOVERY COMPLETED") }
        assert_not_nil completion_log, "Discovery completion log not found"

        # Verify log contains key metrics
        full_log = log_output.join("\n")
        assert_match(/Commanders discovered:\s+20/, full_log)
        assert_match(/Decklist jobs scheduled:\s+20/, full_log)
        assert_match(/Execution time:/, full_log)
      end
    ensure
      # Restore original logger
      Rails.define_singleton_method(:logger) { original_logger }
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job completes quickly (no decklist fetching)
  # ---------------------------------------------------------------------------
  test "discovery completes quickly without fetching decklists" do
    mock_commanders = build_mock_commanders(20)

    stub_edhrec_discovery(top_commanders: mock_commanders) do
      start_time = Time.current
      ScrapeEdhrecCommandersJob.perform_now
      duration = Time.current - start_time

      # Discovery should be very fast (< 5 seconds even with mocks)
      # since it only creates commander records and schedules jobs
      assert duration < 5, "Discovery job took #{duration} seconds, should complete within 5 seconds"
    end
  end

  private

  # Helper to stub EdhrecScraper for discovery-only operations
  def stub_edhrec_discovery(top_commanders:)
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { top_commanders }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  # Build mock commander data
  def build_mock_commanders(count)
    (1..count).map do |i|
      {
        name: "Commander #{i}",
        rank: i,
        url: "https://edhrec.com/commanders/commander-#{i}"
      }
    end
  end

  # Build mock decklist with 100 cards
  def build_mock_decklist
    [
      { name: "Card 1", category: "Commanders", is_commander: true, scryfall_id: "cmd-1" }
    ] + build_mock_cards(99)
  end

  # Build mock card data
  def build_mock_cards(count)
    (1..count).map do |i|
      {
        name: "Card #{i + 1}",
        category: "Artifacts",
        is_commander: false,
        scryfall_id: "card-#{i}"
      }
    end
  end
end
