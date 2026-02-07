require "test_helper"

class CommanderScrapingIntegrationTest < ActiveJob::TestCase
  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all

    # Clear Scryfall cache
    ScryfallCardResolver.clear_cache

    # Clear rate limiter state
    RateLimiter.clear_all_state
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job schedules individual decklist jobs with 1-hour spacing
  # ---------------------------------------------------------------------------
  test "discovery job schedules 20 decklist jobs with 1-hour spacing" do
    mock_commanders = build_mock_commanders(20)

    # Stub EdhrecScraper to return commander list (no decklist fetch)
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { mock_commanders }

    begin
      # Execute the discovery job
      assert_enqueued_jobs 20, only: ScrapeCommanderDecklistJob do
        ScrapeEdhrecCommandersJob.perform_now
      end

      # Verify all 20 commanders were created in database
      assert_equal 20, Commander.count

      # Verify no decklists were created (discovery only)
      assert_equal 0, Decklist.count

      # Verify job scheduling details
      enqueued_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs
      decklist_jobs = enqueued_jobs.select { |j| j[:job] == ScrapeCommanderDecklistJob }

      assert_equal 20, decklist_jobs.length

      # Verify jobs are scheduled with proper timing (0h, 1h, 2h, ..., 19h)
      decklist_jobs.each_with_index do |job, index|
        expected_wait_seconds = index * 3600 # hours to seconds

        # Job should be scheduled with correct wait time
        if job[:at]
          actual_wait_seconds = job[:at].to_f - Time.current.to_f
          # Allow 2 second tolerance for timing
          assert_in_delta expected_wait_seconds, actual_wait_seconds, 2,
                          "Job #{index} should be scheduled #{index}h from now, got #{actual_wait_seconds / 3600}h"
        end
      end
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job creates commanders without updating last_scraped_at
  # ---------------------------------------------------------------------------
  test "discovery job creates commanders without setting last_scraped_at" do
    mock_commanders = build_mock_commanders(5)

    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { mock_commanders }

    begin
      ScrapeEdhrecCommandersJob.perform_now

      # Verify commanders were created
      assert_equal 5, Commander.count

      # Verify last_scraped_at is nil (not set during discovery)
      Commander.all.each do |commander|
        assert_nil commander.last_scraped_at,
                   "Discovery should not set last_scraped_at for #{commander.name}"
      end
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job updates existing commanders rank without affecting last_scraped_at
  # ---------------------------------------------------------------------------
  test "discovery job updates existing commander rank without changing last_scraped_at" do
    # Create existing commander with old rank and scraped timestamp
    existing_commander = Commander.create!(
      name: "Commander 1",
      rank: 10,
      edhrec_url: "https://edhrec.com/commanders/commander-1",
      last_scraped_at: 1.day.ago
    )
    original_timestamp = existing_commander.last_scraped_at

    # Mock scraper to return updated rank
    mock_commanders = [
      { name: "Commander 1", rank: 1, url: "https://edhrec.com/commanders/commander-1" }
    ]

    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { mock_commanders }

    begin
      ScrapeEdhrecCommandersJob.perform_now

      # Verify only 1 commander exists
      assert_equal 1, Commander.count

      # Verify rank was updated
      existing_commander.reload
      assert_equal 1, existing_commander.rank

      # Verify last_scraped_at was NOT changed (discovery doesn't scrape decklists)
      assert_equal original_timestamp.to_i, existing_commander.last_scraped_at.to_i
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Individual decklist job updates last_scraped_at when run
  # ---------------------------------------------------------------------------
  test "decklist job updates last_scraped_at when scraping" do
    commander = Commander.create!(
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test",
      last_scraped_at: nil
    )

    mock_decklist = build_mock_decklist

    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) { |url| mock_decklist }

    begin
      ScrapeCommanderDecklistJob.perform_now(commander.id)

      commander.reload
      assert_not_nil commander.last_scraped_at
      assert commander.last_scraped_at > 1.minute.ago
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Failed decklist scrape doesn't block other commanders
  # ---------------------------------------------------------------------------
  test "failed decklist scrape doesn't prevent other jobs from running" do
    # Create 3 commanders
    commander1 = Commander.create!(name: "Commander 1", rank: 1, edhrec_url: "https://edhrec.com/1")
    commander2 = Commander.create!(name: "Commander 2", rank: 2, edhrec_url: "https://edhrec.com/2")
    commander3 = Commander.create!(name: "Commander 3", rank: 3, edhrec_url: "https://edhrec.com/3")

    mock_decklist = build_mock_decklist

    # Make commander 2 fail
    call_count = 0
    EdhrecScraper.define_singleton_method(:fetch_commander_decklist) do |url|
      call_count += 1
      if url.include?("edhrec.com/2")
        raise EdhrecScraper::FetchError, "Network error"
      else
        mock_decklist
      end
    end

    begin
      # Commander 1 should succeed
      assert_nothing_raised do
        ScrapeCommanderDecklistJob.perform_now(commander1.id)
      end

      # Commander 2 should fail
      assert_raises EdhrecScraper::FetchError do
        ScrapeCommanderDecklistJob.perform_now(commander2.id)
      end

      # Commander 3 should still succeed (independent job)
      assert_nothing_raised do
        ScrapeCommanderDecklistJob.perform_now(commander3.id)
      end

      # Verify 2 decklists created (commanders 1 and 3)
      assert_equal 2, Decklist.count

      # Verify commander 2 has no decklist
      assert_nil Decklist.find_by(commander: commander2)
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_commander_decklist)
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Discovery job handles EDHREC errors appropriately
  # ---------------------------------------------------------------------------
  test "discovery job re-raises EDHREC errors for Solid Queue retry" do
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) do
      raise EdhrecScraper::RateLimitError, "Rate limit exceeded"
    end

    begin
      assert_raises EdhrecScraper::RateLimitError do
        ScrapeEdhrecCommandersJob.perform_now
      end

      # Verify no commanders were created
      assert_equal 0, Commander.count
    ensure
      EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
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
