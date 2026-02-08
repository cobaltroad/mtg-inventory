require "test_helper"

class ScraperExecutionFlowTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    # Clear any existing data
    Decklist.delete_all
    Commander.delete_all
    ScraperExecution.delete_all

    # Clear Scryfall cache to ensure consistent test behavior
    ScryfallCardResolver.clear_cache
  end

  # ---------------------------------------------------------------------------
  # Integration test: Full scraper execution with logging and API visibility
  # ---------------------------------------------------------------------------
  test "full scraper execution creates execution record and is visible via API" do
    # Mock commander data
    mock_commanders = [
      { name: "Atraxa", rank: 1, url: "https://edhrec.com/commanders/atraxa" },
      { name: "Muldrotha", rank: 2, url: "https://edhrec.com/commanders/muldrotha" }
    ]

    # Stub the scraper
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { mock_commanders }

    # Verify no executions exist
    assert_equal 0, ScraperExecution.count

    # Execute the job
    ScrapeEdhrecCommandersJob.perform_now

    # Verify execution record was created
    assert_equal 1, ScraperExecution.count

    execution = ScraperExecution.last
    assert_not_nil execution.started_at
    assert_not_nil execution.finished_at
    assert_equal "success", execution.status
    assert_equal 2, execution.commanders_attempted
    assert_equal 2, execution.commanders_succeeded
    assert_equal 0, execution.commanders_failed
    assert execution.execution_time_seconds.positive?
    assert_equal 100.0, execution.success_rate

    # Verify execution is visible via API
    get api_path("/admin/scraper_executions")
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal execution.id, body[0]["id"]
    assert_equal "success", body[0]["status"]
    assert_equal 2, body[0]["commanders_attempted"]

    # Verify individual execution can be retrieved
    get api_path("/admin/scraper_executions/#{execution.id}")
    assert_response :success

    detail = JSON.parse(response.body)
    assert_equal execution.id, detail["id"]
    assert_equal 100.0, detail["success_rate"]
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  # ---------------------------------------------------------------------------
  # Integration test: Failed execution creates error record
  # ---------------------------------------------------------------------------
  test "failed scraper execution creates execution record with error details" do
    # Stub scraper to raise error
    error = EdhrecScraper::FetchError.new("Connection timeout")
    EdhrecScraper.define_singleton_method(:fetch_top_commanders) { raise error }

    # Execute the job (should raise)
    assert_raises(EdhrecScraper::FetchError) do
      ScrapeEdhrecCommandersJob.perform_now
    end

    # Verify execution record was created with failure status
    assert_equal 1, ScraperExecution.count

    execution = ScraperExecution.last
    assert_equal "failure", execution.status
    assert_not_nil execution.error_summary
    assert_match(/FetchError/, execution.error_summary)
    assert_match(/Connection timeout/, execution.error_summary)

    # Verify failure is visible via API
    get api_path("/admin/scraper_executions?status=failure")
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal execution.id, body[0]["id"]
    assert_equal "failure", body[0]["status"]
  ensure
    EdhrecScraper.singleton_class.send(:remove_method, :fetch_top_commanders)
  end

  # ---------------------------------------------------------------------------
  # Integration test: Multiple executions show correct statistics
  # ---------------------------------------------------------------------------
  test "multiple executions provide accurate statistics via stats endpoint" do
    # Create various execution records
    3.times do
      ScraperExecution.create!(
        started_at: rand(1..5).days.ago,
        finished_at: rand(1..5).days.ago + 5.minutes,
        status: :success,
        commanders_attempted: 20,
        commanders_succeeded: 20
      )
    end

    2.times do
      ScraperExecution.create!(
        started_at: rand(1..5).days.ago,
        finished_at: rand(1..5).days.ago + 3.minutes,
        status: :failure,
        commanders_attempted: 10,
        commanders_failed: 10
      )
    end

    1.times do
      ScraperExecution.create!(
        started_at: 1.day.ago,
        finished_at: 1.day.ago + 10.minutes,
        status: :partial_success,
        commanders_attempted: 20,
        commanders_succeeded: 18,
        commanders_failed: 2
      )
    end

    # Get statistics
    get api_path("/admin/scraper_executions/stats")
    assert_response :success

    stats = JSON.parse(response.body)
    assert_equal 6, stats["total_executions"]
    assert_equal 3, stats["successful_executions"]
    assert_equal 2, stats["failed_executions"]
    assert_equal 1, stats["partial_success_executions"]
    assert_equal 50.0, stats["success_rate"]
  end

  # ---------------------------------------------------------------------------
  # Integration test: Filtering and date range queries
  # ---------------------------------------------------------------------------
  test "API supports filtering executions by status and date range" do
    # Create executions with different dates and statuses
    old_success = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-01-15T10:00:00Z"),
      finished_at: Time.zone.parse("2026-01-15T10:05:00Z"),
      status: :success
    )

    recent_failure = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-08T10:00:00Z"),
      finished_at: Time.zone.parse("2026-02-08T10:03:00Z"),
      status: :failure
    )

    recent_success = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-07T10:00:00Z"),
      finished_at: Time.zone.parse("2026-02-07T10:08:00Z"),
      status: :success
    )

    # Filter by status
    get api_path("/admin/scraper_executions?status=success")
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    ids = body.map { |e| e["id"] }
    assert_includes ids, old_success.id
    assert_includes ids, recent_success.id

    # Filter by date range
    get api_path("/admin/scraper_executions?start_date=2026-02-01")
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 2, body.length
    ids = body.map { |e| e["id"] }
    assert_includes ids, recent_failure.id
    assert_includes ids, recent_success.id

    # Combine filters
    get api_path("/admin/scraper_executions?status=success&start_date=2026-02-01")
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.length
    assert_equal recent_success.id, body[0]["id"]
  end
end
