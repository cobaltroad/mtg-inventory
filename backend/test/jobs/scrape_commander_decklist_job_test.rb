require "test_helper"

class ScrapeCommanderDecklistJobTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all

    # Clear Scryfall cache to ensure consistent test behavior
    ScryfallCardResolver.clear_cache

    # Clear rate limiter state
    RateLimiter.clear_all_state
  end

  # ---------------------------------------------------------------------------
  # Test: Job enqueues successfully
  # ---------------------------------------------------------------------------
  test "job enqueues successfully with commander_id" do
    commander = create_test_commander

    assert_enqueued_with(job: ScrapeCommanderDecklistJob, args: [commander.id]) do
      ScrapeCommanderDecklistJob.perform_later(commander.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job fetches and saves decklist for a commander
  # ---------------------------------------------------------------------------
  test "fetches and saves decklist for existing commander" do
    commander = create_test_commander
    mock_decklist = build_mock_decklist

    stub_edhrec_scraper(decklist: mock_decklist) do
      # Execute the job
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      # Verify decklist was created
      assert_equal 1, Decklist.count

      # Verify decklist has correct contents
      decklist = commander.decklists.reload.first
      assert_not_nil decklist
      assert_equal 100, decklist.contents.length
      assert decklist.contents.any? { |c| c["card_name"] == "Card 1" }
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job updates last_scraped_at timestamp
  # ---------------------------------------------------------------------------
  test "updates commander last_scraped_at timestamp" do
    commander = create_test_commander(last_scraped_at: 1.day.ago)
    original_timestamp = commander.last_scraped_at
    mock_decklist = build_mock_decklist

    stub_edhrec_scraper(decklist: mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      commander.reload
      assert commander.last_scraped_at > original_timestamp
      assert commander.last_scraped_at > 1.minute.ago
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job replaces existing decklist contents
  # ---------------------------------------------------------------------------
  test "replaces existing decklist contents on re-scrape" do
    commander = create_test_commander

    # Create existing decklist with old data
    old_decklist = Decklist.create!(
      commander: commander,
      contents: [
        { card_id: "old-id-1", card_name: "Old Card 1", quantity: 1 },
        { card_id: "old-id-2", card_name: "Old Card 2", quantity: 1 }
      ]
    )

    mock_decklist = build_mock_decklist

    stub_edhrec_scraper(decklist: mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      # Verify only 1 decklist exists (updated, not duplicated)
      assert_equal 1, Decklist.count

      # Verify contents were replaced
      old_decklist.reload
      assert_equal 100, old_decklist.contents.length
      assert_not old_decklist.contents.any? { |c| c["card_name"] == "Old Card 1" }
      assert old_decklist.contents.any? { |c| c["card_name"] == "Card 1" }
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job handles commander not found error
  # ---------------------------------------------------------------------------
  test "raises error if commander does not exist" do
    non_existent_id = 99999

    assert_raises ActiveRecord::RecordNotFound do
      ScrapeCommanderDecklistJob.perform_now(non_existent_id)
    end

    # Verify no decklist was created
    assert_equal 0, Decklist.count
  end

  # ---------------------------------------------------------------------------
  # Test: Job handles EDHREC fetch errors gracefully
  # ---------------------------------------------------------------------------
  test "handles EDHREC fetch errors and re-raises for Solid Queue retry" do
    commander = create_test_commander

    # Stub to raise network error
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) do |url|
      raise EdhrecScraper::FetchError, "Network timeout"
    end

    begin
      # Should re-raise the error so Solid Queue can retry the job
      assert_raises EdhrecScraper::FetchError do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      # Verify no decklist was created
      assert_equal 0, Decklist.count
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job handles EDHREC parse errors
  # ---------------------------------------------------------------------------
  test "handles EDHREC parse errors and re-raises for retry" do
    commander = create_test_commander

    # Stub to raise parse error
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) do |url|
      raise EdhrecScraper::ParseError, "Invalid JSON structure"
    end

    begin
      assert_raises EdhrecScraper::ParseError do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      # Verify no decklist was created
      assert_equal 0, Decklist.count
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job handles rate limit errors and re-raises
  # ---------------------------------------------------------------------------
  test "handles rate limit errors and re-raises for retry" do
    commander = create_test_commander

    # Stub to raise rate limit error
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) do |url|
      raise EdhrecScraper::RateLimitError, "Rate limit exceeded"
    end

    begin
      assert_raises EdhrecScraper::RateLimitError do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      # Verify no decklist was created
      assert_equal 0, Decklist.count
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job logs progress appropriately
  # ---------------------------------------------------------------------------
  test "logs commander name and progress" do
    commander = create_test_commander
    mock_decklist = build_mock_decklist

    # Capture log output
    log_output = []
    original_logger = Rails.logger

    logger = Logger.new(nil)
    logger.define_singleton_method(:info) { |message| log_output << message }
    logger.define_singleton_method(:debug) { |message| log_output << message }
    logger.define_singleton_method(:error) { |message| log_output << message }

    Rails.define_singleton_method(:logger) { logger }

    begin
      stub_edhrec_scraper(decklist: mock_decklist) do
        ScrapeCommanderDecklistJob.perform_now(commander.id)

        # Verify logs mention the commander name
        full_log = log_output.join("\n")
        assert_match(/Test Commander/, full_log)
        assert_match(/Fetching decklist/, full_log)
      end
    ensure
      Rails.define_singleton_method(:logger) { original_logger }
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job can handle commanders with special characters in names
  # ---------------------------------------------------------------------------
  test "handles commander names with special characters" do
    commander = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice"
    )

    mock_decklist = build_mock_decklist

    stub_edhrec_scraper(decklist: mock_decklist) do
      assert_nothing_raised do
        ScrapeCommanderDecklistJob.perform_now(commander.id)
      end

      assert_equal 1, Decklist.count
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Job preserves commander attributes (doesn't modify rank, etc.)
  # ---------------------------------------------------------------------------
  test "does not modify commander rank or edhrec_url" do
    commander = create_test_commander(rank: 5)
    original_rank = commander.rank
    original_url = commander.edhrec_url
    mock_decklist = build_mock_decklist

    stub_edhrec_scraper(decklist: mock_decklist) do
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      commander.reload
      assert_equal original_rank, commander.rank
      assert_equal original_url, commander.edhrec_url
    end
  end

  private

  # Helper to create a test commander
  def create_test_commander(attrs = {})
    Commander.create!({
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test-commander",
      last_scraped_at: nil
    }.merge(attrs))
  end

  # Helper to stub EdhrecScraper with proper cleanup
  def stub_edhrec_scraper(decklist:)
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |url| decklist }
    yield
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
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
