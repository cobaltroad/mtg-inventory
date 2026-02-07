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
  # Test: Job processes all 20 commanders successfully
  # ---------------------------------------------------------------------------
  test "processes all 20 commanders and creates database records" do
    # Mock the external services
    mock_commanders = build_mock_commanders(20)
    mock_decklist = build_mock_decklist

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
        # Execute the job
        ScrapeEdhrecCommandersJob.perform_now

        # Verify all 20 commanders were created
        assert_equal 20, Commander.count

        # Verify all 20 decklists were created
        assert_equal 20, Decklist.count

        # Verify first commander has expected attributes
        first_commander = Commander.find_by(name: "Commander 1")
        assert_not_nil first_commander
        assert_equal 1, first_commander.rank
        assert_equal "https://edhrec.com/commanders/commander-1", first_commander.edhrec_url
        assert_not_nil first_commander.last_scraped_at

        # Verify decklist has JSONB contents
        decklist = first_commander.decklists.first
        assert_not_nil decklist
        assert_kind_of Array, decklist.contents
        assert_equal 100, decklist.contents.length
      end
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

    # Mock the scraper to return the same commander with updated data
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]
    mock_decklist = build_mock_decklist

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
        # Execute the job
        ScrapeEdhrecCommandersJob.perform_now

        # Verify only 1 commander exists (not 2)
        assert_equal 1, Commander.count

        # Verify commander was updated, not duplicated
        existing_commander.reload
        assert_equal 1, existing_commander.rank
        assert_equal "https://edhrec.com/commanders/commander-1", existing_commander.edhrec_url
        assert existing_commander.last_scraped_at > 1.minute.ago

        # Verify created_at timestamp was preserved
        assert existing_commander.created_at < 1.minute.ago
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Decklist JSONB contents replaced on update
  # ---------------------------------------------------------------------------
  test "replaces decklist contents on subsequent scrapes" do
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

    # Mock new scrape data
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]
    mock_decklist = build_mock_decklist

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
        # Execute the job
        ScrapeEdhrecCommandersJob.perform_now

        # Verify decklist was updated, not duplicated
        assert_equal 1, Decklist.count

        # Verify contents were replaced
        old_decklist.reload
        assert_equal 100, old_decklist.contents.length

        # Verify old contents are gone
        assert_not old_decklist.contents.any? { |c| c["card_name"] == "Old Card 1" }

        # Verify new contents are present
        assert old_decklist.contents.any? { |c| c["card_name"] == "Card 1" }
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Per-commander transaction isolation (one failure doesn't affect others)
  # ---------------------------------------------------------------------------
  test "processes remaining commanders after one fails" do
    # Mock 3 commanders, but make the 2nd one fail
    mock_commanders = build_mock_commanders(3)
    mock_decklist = build_mock_decklist

    # Stub to make the 2nd commander fail
    call_count = 0
    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, ->(url) do
        call_count += 1
        if url.include?("commander-2")
          raise EdhrecScraper::FetchError, "Network timeout"
        else
          mock_decklist
        end
      end do
        # Execute the job - should not raise error
        assert_nothing_raised do
          ScrapeEdhrecCommandersJob.perform_now
        end

        # Verify commanders 1 and 3 were created successfully
        assert_equal 2, Commander.count
        assert_not_nil Commander.find_by(name: "Commander 1")
        assert_nil Commander.find_by(name: "Commander 2")
        assert_not_nil Commander.find_by(name: "Commander 3")

        # Verify decklists for successful commanders
        assert_equal 2, Decklist.count
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Retry logic for transient errors
  # ---------------------------------------------------------------------------
  test "retries failed commanders up to 3 times before skipping" do
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]

    # Track retry attempts
    attempt_count = 0

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, ->(url) do
        attempt_count += 1
        raise EdhrecScraper::FetchError, "Transient network error"
      end do
        # Execute the job
        ScrapeEdhrecCommandersJob.perform_now

        # Verify it attempted 3 retries (4 total attempts: initial + 3 retries)
        assert_equal 4, attempt_count

        # Verify commander was not created after max retries
        assert_equal 0, Commander.count
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Fatal error handling (database down, etc.)
  # ---------------------------------------------------------------------------
  test "raises fatal errors to Solid Queue for retry logic" do
    mock_commanders = build_mock_commanders(1)

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      # Simulate database connection failure
      Commander.stub :find_or_initialize_by, ->(*args) { raise ActiveRecord::ConnectionNotEstablished, "Database unavailable" } do
        # Verify the fatal error is raised, not caught
        assert_raises ActiveRecord::ConnectionNotEstablished do
          ScrapeEdhrecCommandersJob.perform_now
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Summary logging includes all required metrics
  # ---------------------------------------------------------------------------
  test "logs comprehensive summary after completion" do
    mock_commanders = build_mock_commanders(20)
    mock_decklist = build_mock_decklist

    # Capture log output
    log_output = []
    original_logger = Rails.logger

    # Create a simple logger that captures messages
    logger = Logger.new(nil)
    logger.define_singleton_method(:info) { |message| log_output << message }
    logger.define_singleton_method(:warn) { |message| log_output << message }
    logger.define_singleton_method(:error) { |message| log_output << message }

    Rails.stub :logger, logger do
      EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
        EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
          ScrapeEdhrecCommandersJob.perform_now

          # Verify summary log contains required metrics
          summary_log = log_output.find { |msg| msg.include?("ScrapeEdhrecCommandersJob completed") }
          assert_not_nil summary_log, "Summary log not found"

          # Verify log contains key metrics
          assert_match(/Total commanders attempted: 20/, summary_log)
          assert_match(/Successfully scraped: 20/, summary_log)
          assert_match(/Failed: 0/, summary_log)
          assert_match(/Execution time:/, summary_log)
          assert_match(/Total cards inserted\/updated:/, summary_log)
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: TSVECTOR updated automatically after decklist changes
  # ---------------------------------------------------------------------------
  test "updates TSVECTOR when decklist contents change" do
    mock_commanders = [
      { name: "Atraxa, Praetors' Voice", rank: 1, url: "https://edhrec.com/commanders/atraxa" }
    ]

    mock_decklist = [
      { name: "Atraxa, Praetors' Voice", category: "Commanders", is_commander: true, scryfall_id: "cmd-xyz" },
      { name: "Sol Ring", category: "Artifacts", is_commander: false, scryfall_id: "abc-123" },
      { name: "Command Tower", category: "Lands", is_commander: false, scryfall_id: "def-456" }
    ] + build_mock_cards(97) # Total 100 cards

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
        ScrapeEdhrecCommandersJob.perform_now

        # Verify decklist was created
        commander = Commander.find_by(name: "Atraxa, Praetors' Voice")
        decklist = commander.decklists.first

        # Verify TSVECTOR contains searchable card names
        assert_not_nil decklist.vector

        # Verify we can search by card name using TSVECTOR
        result = Decklist.where("vector @@ to_tsquery('english', ?)", "Sol & Ring").first
        assert_equal decklist.id, result&.id, "TSVECTOR should allow full-text search on card names"
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job completes within time limit
  # ---------------------------------------------------------------------------
  test "completes within 30 minutes" do
    mock_commanders = build_mock_commanders(20)
    mock_decklist = build_mock_decklist

    EdhrecScraper.stub :fetch_top_commanders, mock_commanders do
      EdhrecScraper.stub :fetch_commander_decklist, mock_decklist do
        start_time = Time.current
        ScrapeEdhrecCommandersJob.perform_now
        duration = Time.current - start_time

        # Verify execution time is under 30 minutes (1800 seconds)
        # With mocks, this should be very fast, but we're testing the constraint
        assert duration < 1800, "Job took #{duration} seconds, should complete within 1800 seconds"
      end
    end
  end

  private

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
