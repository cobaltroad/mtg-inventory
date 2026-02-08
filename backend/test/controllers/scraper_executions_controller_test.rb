require "test_helper"

class ScraperExecutionsControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    # Clear existing data
    ScraperExecution.delete_all
  end

  # ---------------------------------------------------------------------------
  # #index - List all executions ordered by most recent
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions returns 200 and empty array when no executions exist" do
    get api_path("/admin/scraper_executions")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body
  end

  test "GET /api/admin/scraper_executions returns all executions ordered by most recent first" do
    # Create executions in non-chronological order to verify sorting
    old_execution = ScraperExecution.create!(
      started_at: 3.days.ago,
      finished_at: 3.days.ago + 5.minutes,
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20
    )

    recent_execution = ScraperExecution.create!(
      started_at: 1.hour.ago,
      finished_at: 1.hour.ago + 3.minutes,
      status: :success,
      commanders_attempted: 15,
      commanders_succeeded: 15
    )

    middle_execution = ScraperExecution.create!(
      started_at: 1.day.ago,
      finished_at: 1.day.ago + 10.minutes,
      status: :partial_success,
      commanders_attempted: 20,
      commanders_succeeded: 18,
      commanders_failed: 2
    )

    get api_path("/admin/scraper_executions")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 3, body.length

    # Verify ordering by most recent first
    assert_equal recent_execution.id, body[0]["id"]
    assert_equal middle_execution.id, body[1]["id"]
    assert_equal old_execution.id, body[2]["id"]
  end

  test "GET /api/admin/scraper_executions includes all execution attributes" do
    execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-08T10:00:00Z"),
      finished_at: Time.zone.parse("2026-02-08T10:05:30Z"),
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20,
      commanders_failed: 0,
      total_cards_processed: 2000
    )

    get api_path("/admin/scraper_executions")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    result = body[0]

    assert_equal execution.id, result["id"]
    assert_equal "2026-02-08T10:00:00.000Z", result["started_at"]
    assert_equal "2026-02-08T10:05:30.000Z", result["finished_at"]
    assert_equal "success", result["status"]
    assert_equal 20, result["commanders_attempted"]
    assert_equal 20, result["commanders_succeeded"]
    assert_equal 0, result["commanders_failed"]
    assert_equal 2000, result["total_cards_processed"]
    assert_equal 330.0, result["execution_time_seconds"]
    assert_equal 100.0, result["success_rate"]
  end

  test "GET /api/admin/scraper_executions includes error_summary when present" do
    execution = ScraperExecution.create!(
      started_at: 1.hour.ago,
      finished_at: 1.hour.ago + 1.minute,
      status: :failure,
      error_summary: "EdhrecScraper::FetchError: Connection timeout after 30s"
    )

    get api_path("/admin/scraper_executions")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal "EdhrecScraper::FetchError: Connection timeout after 30s", body[0]["error_summary"]
  end

  # ---------------------------------------------------------------------------
  # #index - Filtering by status
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions?status=success filters by success status" do
    success_execution = ScraperExecution.create!(
      started_at: 2.hours.ago,
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20
    )

    failure_execution = ScraperExecution.create!(
      started_at: 1.hour.ago,
      status: :failure,
      commanders_attempted: 5,
      commanders_succeeded: 0,
      commanders_failed: 5
    )

    partial_execution = ScraperExecution.create!(
      started_at: 3.hours.ago,
      status: :partial_success,
      commanders_attempted: 20,
      commanders_succeeded: 18,
      commanders_failed: 2
    )

    get api_path("/admin/scraper_executions?status=success")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal success_execution.id, body[0]["id"]
    assert_equal "success", body[0]["status"]
  end

  test "GET /api/admin/scraper_executions?status=failure filters by failure status" do
    ScraperExecution.create!(started_at: 2.hours.ago, status: :success)
    failure = ScraperExecution.create!(started_at: 1.hour.ago, status: :failure)

    get api_path("/admin/scraper_executions?status=failure")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal failure.id, body[0]["id"]
  end

  test "GET /api/admin/scraper_executions?status=partial_success filters by partial_success status" do
    ScraperExecution.create!(started_at: 2.hours.ago, status: :success)
    partial = ScraperExecution.create!(started_at: 1.hour.ago, status: :partial_success)

    get api_path("/admin/scraper_executions?status=partial_success")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal partial.id, body[0]["id"]
  end

  # ---------------------------------------------------------------------------
  # #index - Filtering by date range
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions?start_date filters by start date" do
    old_execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-01T10:00:00Z"),
      status: :success
    )

    recent_execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-08T10:00:00Z"),
      status: :success
    )

    get api_path("/admin/scraper_executions?start_date=2026-02-05")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal recent_execution.id, body[0]["id"]
  end

  test "GET /api/admin/scraper_executions?end_date filters by end date" do
    old_execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-01T10:00:00Z"),
      status: :success
    )

    recent_execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-08T10:00:00Z"),
      status: :success
    )

    get api_path("/admin/scraper_executions?end_date=2026-02-05")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal old_execution.id, body[0]["id"]
  end

  test "GET /api/admin/scraper_executions?start_date&end_date filters by date range" do
    before_range = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-01-15T10:00:00Z"),
      status: :success
    )

    in_range_1 = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-02T10:00:00Z"),
      status: :success
    )

    in_range_2 = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-05T10:00:00Z"),
      status: :failure
    )

    after_range = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-10T10:00:00Z"),
      status: :success
    )

    get api_path("/admin/scraper_executions?start_date=2026-02-01&end_date=2026-02-07")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 2, body.length
    ids = body.map { |e| e["id"] }
    assert_includes ids, in_range_1.id
    assert_includes ids, in_range_2.id
  end

  # ---------------------------------------------------------------------------
  # #index - Pagination
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions?limit limits the number of results" do
    # Create 10 executions
    10.times do |i|
      ScraperExecution.create!(
        started_at: (10 - i).hours.ago,
        status: :success
      )
    end

    get api_path("/admin/scraper_executions?limit=5")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 5, body.length
  end

  test "GET /api/admin/scraper_executions defaults to 50 results maximum" do
    # Create 60 executions
    60.times do |i|
      ScraperExecution.create!(
        started_at: (60 - i).hours.ago,
        status: :success
      )
    end

    get api_path("/admin/scraper_executions")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 50, body.length
  end

  # ---------------------------------------------------------------------------
  # #show - Get a specific execution
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions/:id returns execution details" do
    execution = ScraperExecution.create!(
      started_at: Time.zone.parse("2026-02-08T10:00:00Z"),
      finished_at: Time.zone.parse("2026-02-08T10:05:00Z"),
      status: :success,
      commanders_attempted: 15,
      commanders_succeeded: 15,
      commanders_failed: 0,
      total_cards_processed: 1500
    )

    get api_path("/admin/scraper_executions/#{execution.id}")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal execution.id, body["id"]
    assert_equal "2026-02-08T10:00:00.000Z", body["started_at"]
    assert_equal "2026-02-08T10:05:00.000Z", body["finished_at"]
    assert_equal "success", body["status"]
    assert_equal 15, body["commanders_attempted"]
    assert_equal 15, body["commanders_succeeded"]
    assert_equal 0, body["commanders_failed"]
    assert_equal 1500, body["total_cards_processed"]
    assert_equal 300.0, body["execution_time_seconds"]
    assert_equal 100.0, body["success_rate"]
  end

  test "GET /api/admin/scraper_executions/:id returns 404 when execution not found" do
    get api_path("/admin/scraper_executions/99999")

    assert_response :not_found
    body = JSON.parse(response.body)

    assert_equal "Execution not found", body["error"]
  end

  # ---------------------------------------------------------------------------
  # #show - Includes error_summary
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions/:id includes error_summary when present" do
    execution = ScraperExecution.create!(
      started_at: 1.hour.ago,
      finished_at: 1.hour.ago + 30.seconds,
      status: :failure,
      error_summary: "Network error: Connection refused"
    )

    get api_path("/admin/scraper_executions/#{execution.id}")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "Network error: Connection refused", body["error_summary"]
  end

  # ---------------------------------------------------------------------------
  # #stats - Execution statistics (trend data)
  # ---------------------------------------------------------------------------
  test "GET /api/admin/scraper_executions/stats returns success rate over time" do
    # Create executions with different statuses
    5.times do
      ScraperExecution.create!(
        started_at: rand(1..10).days.ago,
        status: :success,
        commanders_attempted: 20,
        commanders_succeeded: 20
      )
    end

    3.times do
      ScraperExecution.create!(
        started_at: rand(1..10).days.ago,
        status: :failure,
        commanders_attempted: 10,
        commanders_succeeded: 0,
        commanders_failed: 10
      )
    end

    2.times do
      ScraperExecution.create!(
        started_at: rand(1..10).days.ago,
        status: :partial_success,
        commanders_attempted: 20,
        commanders_succeeded: 15,
        commanders_failed: 5
      )
    end

    get api_path("/admin/scraper_executions/stats")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 10, body["total_executions"]
    assert_equal 5, body["successful_executions"]
    assert_equal 3, body["failed_executions"]
    assert_equal 2, body["partial_success_executions"]
    assert_equal 50.0, body["success_rate"]
  end
end
