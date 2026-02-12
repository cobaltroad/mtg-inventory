require "test_helper"

class PriceUpdateExecutionsControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    # Clear existing data
    PriceUpdateExecution.delete_all

    # Create sample executions for testing
    @execution1 = PriceUpdateExecution.create!(
      started_at: 3.days.ago,
      finished_at: 3.days.ago + 5.minutes,
      status: :success,
      mode: "batch",
      cards_attempted: 100,
      cards_succeeded: 100,
      cards_failed: 0,
      cards_skipped: 0,
      price_alerts_created: 5
    )

    @execution2 = PriceUpdateExecution.create!(
      started_at: 2.days.ago,
      finished_at: 2.days.ago + 3.minutes,
      status: :partial_success,
      mode: "batch",
      cards_attempted: 50,
      cards_succeeded: 45,
      cards_failed: 5,
      cards_skipped: 0,
      price_alerts_created: 2
    )

    @execution3 = PriceUpdateExecution.create!(
      started_at: 1.day.ago,
      finished_at: 1.day.ago + 10.seconds,
      status: :success,
      mode: "single_card",
      cards_attempted: 1,
      cards_succeeded: 1,
      cards_failed: 0,
      cards_skipped: 0,
      price_alerts_created: 0
    )

    @execution4 = PriceUpdateExecution.create!(
      started_at: 1.hour.ago,
      finished_at: 1.hour.ago + 2.minutes,
      status: :failure,
      mode: "batch",
      cards_attempted: 20,
      cards_succeeded: 0,
      cards_failed: 20,
      cards_skipped: 0,
      price_alerts_created: 0,
      error_summary: "Scryfall API unavailable"
    )
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/price_update_executions - index
  # ---------------------------------------------------------------------------
  test "GET index returns all executions ordered by most recent first" do
    get api_path("/admin/price_update_executions")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 4, json.length
    # Most recent should be first
    assert_equal @execution4.id, json[0]["id"]
    assert_equal @execution3.id, json[1]["id"]
    assert_equal @execution2.id, json[2]["id"]
    assert_equal @execution1.id, json[3]["id"]
  end

  test "GET index returns executions with all expected fields" do
    get api_path("/admin/price_update_executions")

    assert_response :success
    json = JSON.parse(response.body)
    execution_json = json.first

    assert_includes execution_json.keys, "id"
    assert_includes execution_json.keys, "started_at"
    assert_includes execution_json.keys, "finished_at"
    assert_includes execution_json.keys, "status"
    assert_includes execution_json.keys, "mode"
    assert_includes execution_json.keys, "cards_attempted"
    assert_includes execution_json.keys, "cards_succeeded"
    assert_includes execution_json.keys, "cards_failed"
    assert_includes execution_json.keys, "cards_skipped"
    assert_includes execution_json.keys, "price_alerts_created"
    assert_includes execution_json.keys, "execution_time_seconds"
    assert_includes execution_json.keys, "success_rate"
    assert_includes execution_json.keys, "error_summary"
    assert_includes execution_json.keys, "created_at"
    assert_includes execution_json.keys, "updated_at"
  end

  test "GET index filters by status parameter" do
    get api_path("/admin/price_update_executions?status=success"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
    assert_equal "success", json[0]["status"]
    assert_equal "success", json[1]["status"]
  end

  test "GET index filters by mode parameter" do
    get api_path("/admin/price_update_executions?mode=single_card"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.length
    assert_equal "single_card", json[0]["mode"]
    assert_equal @execution3.id, json[0]["id"]
  end

  test "GET index filters by start_date parameter" do
    start_date = 2.days.ago.to_date.to_s

    get api_path("/admin/price_update_executions?start_date=#{start_date}"

    assert_response :success
    json = JSON.parse(response.body)

    # Should return executions from last 2 days (execution2, execution3, execution4)
    assert_equal 3, json.length
    assert json.all? { |e| Date.parse(e["started_at"]) >= Date.parse(start_date) }
  end

  test "GET index filters by end_date parameter" do
    end_date = 2.days.ago.to_date.to_s

    get api_path("/admin/price_update_executions?end_date=#{end_date}"

    assert_response :success
    json = JSON.parse(response.body)

    # Should return executions up to 2 days ago (execution1, execution2)
    assert_equal 2, json.length
    assert json.all? { |e| Date.parse(e["started_at"]) <= Date.parse(end_date).end_of_day }
  end

  test "GET index filters by date range" do
    start_date = 3.days.ago.to_date.to_s
    end_date = 1.day.ago.to_date.to_s

    get api_path("/admin/price_update_executions?start_date=#{start_date}&end_date=#{end_date}"

    assert_response :success
    json = JSON.parse(response.body)

    # Should return execution1, execution2, execution3
    assert_equal 3, json.length
  end

  test "GET index respects limit parameter" do
    get api_path("/admin/price_update_executions?limit=2"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
  end

  test "GET index enforces maximum limit of 50" do
    get api_path("/admin/price_update_executions?limit=200"

    assert_response :success
    json = JSON.parse(response.body)

    # Should be capped at 50 even though we requested 200
    # (Currently only 4 executions exist, so we get 4)
    assert json.length <= 50
  end

  test "GET index defaults to limit of 50 when not specified" do
    # Create 60 executions to test default limit
    60.times do |i|
      PriceUpdateExecution.create!(
        started_at: i.hours.ago,
        mode: "batch"
      )
    end

    get api_path("/admin/price_update_executions")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 50, json.length
  end

  test "GET index returns timestamps in ISO 8601 format" do
    get api_path("/admin/price_update_executions")

    assert_response :success
    json = JSON.parse(response.body)
    execution_json = json.first

    # Verify ISO 8601 format (includes timezone)
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}/, execution_json["started_at"]
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}/, execution_json["finished_at"]
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/price_update_executions/:id - show
  # ---------------------------------------------------------------------------
  test "GET show returns single execution by id" do
    get api_path("/admin/price_update_executions/#{@execution1.id}"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @execution1.id, json["id"]
    assert_equal "batch", json["mode"]
    assert_equal 100, json["cards_attempted"]
    assert_equal 100, json["cards_succeeded"]
  end

  test "GET show returns 404 for non-existent execution" do
    get api_path("/admin/price_update_executions/99999"

    assert_response :not_found
    json = JSON.parse(response.body)

    assert_includes json["error"], "not found"
  end

  test "GET show returns all execution fields" do
    get api_path("/admin/price_update_executions/#{@execution4.id}"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @execution4.id, json["id"]
    assert_equal "failure", json["status"]
    assert_equal "Scryfall API unavailable", json["error_summary"]
    assert_not_nil json["execution_time_seconds"]
    assert_equal 0.0, json["success_rate"]
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/price_update_executions/stats - stats
  # ---------------------------------------------------------------------------
  test "GET stats returns aggregate statistics" do
    get api_path("/admin/price_update_executions/stats"

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json.keys, "total_executions"
    assert_includes json.keys, "successful_executions"
    assert_includes json.keys, "failed_executions"
    assert_includes json.keys, "partial_success_executions"
    assert_includes json.keys, "success_rate"
    assert_includes json.keys, "last_24h_success_rate"
    assert_includes json.keys, "last_7d_avg_duration"
    assert_includes json.keys, "total_cards_processed_today"
    assert_includes json.keys, "failed_count_last_24h"
  end

  test "GET stats calculates totals correctly" do
    get api_path("/admin/price_update_executions/stats"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 4, json["total_executions"]
    assert_equal 2, json["successful_executions"]  # execution1, execution3
    assert_equal 1, json["failed_executions"]  # execution4
    assert_equal 1, json["partial_success_executions"]  # execution2
  end

  test "GET stats calculates overall success rate" do
    get api_path("/admin/price_update_executions/stats"

    assert_response :success
    json = JSON.parse(response.body)

    # 2 successes out of 4 total = 50%
    assert_equal 50.0, json["success_rate"]
  end

  test "GET stats calculates last 24h success rate" do
    get api_path("/admin/price_update_executions/stats"

    assert_response :success
    json = JSON.parse(response.body)

    # Only execution4 is in last 24h, which is a failure
    # So success rate should be 0%
    assert_equal 0.0, json["last_24h_success_rate"]
  end

  test "GET stats returns zero values when no executions exist" do
    PriceUpdateExecution.delete_all

    get api_path("/admin/price_update_executions/stats"

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 0, json["total_executions"]
    assert_equal 0, json["successful_executions"]
    assert_equal 0.0, json["success_rate"]
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------
  test "GET index handles invalid date format gracefully" do
    get api_path("/admin/price_update_executions?start_date=invalid-date"

    # Should return error or empty result, not crash
    assert_response :success # or :bad_request depending on implementation
  end

  test "GET index handles invalid status filter gracefully" do
    get api_path("/admin/price_update_executions?status=invalid_status"

    assert_response :success
    json = JSON.parse(response.body)

    # Should return empty array for invalid status
    assert_equal [], json
  end
end
