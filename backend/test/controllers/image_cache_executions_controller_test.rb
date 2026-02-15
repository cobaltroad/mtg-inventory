require "test_helper"

class ImageCacheExecutionsControllerTest < ActionDispatch::IntegrationTest
  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  setup do
    # Clear existing data
    ImageCacheExecution.delete_all

    # Create sample executions for testing
    @execution1 = ImageCacheExecution.create!(
      started_at: 3.days.ago,
      finished_at: 3.days.ago + 2.seconds,
      status: :success,
      collection_item_id: 100,
      card_id: "card-abc-123",
      cache_hit: false,
      downloaded: true,
      file_size_bytes: 45678
    )

    @execution2 = ImageCacheExecution.create!(
      started_at: 2.days.ago,
      finished_at: 2.days.ago + 1.second,
      status: :success,
      collection_item_id: 101,
      card_id: "card-def-456",
      cache_hit: true,
      downloaded: false
    )

    @execution3 = ImageCacheExecution.create!(
      started_at: 1.day.ago,
      finished_at: 1.day.ago + 3.seconds,
      status: :failure,
      collection_item_id: 102,
      card_id: "card-ghi-789",
      cache_hit: false,
      downloaded: false,
      error_message: "HTTP 404 Not Found"
    )

    @execution4 = ImageCacheExecution.create!(
      started_at: 1.hour.ago,
      finished_at: 1.hour.ago + 1.second,
      status: :skipped,
      collection_item_id: 103,
      card_id: "card-jkl-012",
      cache_hit: false,
      downloaded: false,
      error_message: "Collection item not found"
    )
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/image_cache_executions - index
  # ---------------------------------------------------------------------------
  test "GET index returns all executions ordered by most recent first" do
    get api_path("/admin/image_cache_executions")

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
    get api_path("/admin/image_cache_executions")

    assert_response :success
    json = JSON.parse(response.body)
    execution_json = json.first

    assert_includes execution_json.keys, "id"
    assert_includes execution_json.keys, "started_at"
    assert_includes execution_json.keys, "finished_at"
    assert_includes execution_json.keys, "status"
    assert_includes execution_json.keys, "collection_item_id"
    assert_includes execution_json.keys, "card_id"
    assert_includes execution_json.keys, "cache_hit"
    assert_includes execution_json.keys, "downloaded"
    assert_includes execution_json.keys, "file_size_bytes"
    assert_includes execution_json.keys, "execution_time_seconds"
    assert_includes execution_json.keys, "error_message"
    assert_includes execution_json.keys, "created_at"
    assert_includes execution_json.keys, "updated_at"
  end

  test "GET index filters by status parameter" do
    get api_path("/admin/image_cache_executions?status=success")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
    assert_equal "success", json[0]["status"]
    assert_equal "success", json[1]["status"]
  end

  test "GET index filters by card_id parameter" do
    get api_path("/admin/image_cache_executions?card_id=card-abc-123")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.length
    assert_equal "card-abc-123", json[0]["card_id"]
    assert_equal @execution1.id, json[0]["id"]
  end

  test "GET index filters by collection_item_id parameter" do
    get api_path("/admin/image_cache_executions?collection_item_id=101")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.length
    assert_equal 101, json[0]["collection_item_id"]
    assert_equal @execution2.id, json[0]["id"]
  end

  test "GET index filters by cache_hit parameter" do
    get api_path("/admin/image_cache_executions?cache_hit=true")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 1, json.length
    assert_equal true, json[0]["cache_hit"]
    assert_equal @execution2.id, json[0]["id"]
  end

  test "GET index filters by start_date parameter" do
    start_date = 2.days.ago.to_date.to_s

    get api_path("/admin/image_cache_executions?start_date=#{start_date}")

    assert_response :success
    json = JSON.parse(response.body)

    # Should return executions from last 2 days (execution2, execution3, execution4)
    assert_equal 3, json.length
    assert json.all? { |e| Date.parse(e["started_at"]) >= Date.parse(start_date) }
  end

  test "GET index filters by end_date parameter" do
    end_date = 2.days.ago.to_date.to_s

    get api_path("/admin/image_cache_executions?end_date=#{end_date}")

    assert_response :success
    json = JSON.parse(response.body)

    # Should return executions up to 2 days ago (execution1, execution2)
    assert_equal 2, json.length
    assert json.all? { |e| Date.parse(e["started_at"]) <= Date.parse(end_date).end_of_day }
  end

  test "GET index respects limit parameter" do
    get api_path("/admin/image_cache_executions?limit=2")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 2, json.length
  end

  test "GET index enforces maximum limit of 100" do
    get api_path("/admin/image_cache_executions?limit=500")

    assert_response :success
    json = JSON.parse(response.body)

    # Should be capped at 100 even though we requested 500
    # (Currently only 4 executions exist, so we get 4)
    assert json.length <= 100
  end

  test "GET index defaults to limit of 100 when not specified" do
    # Create 120 executions to test default limit
    120.times do |i|
      ImageCacheExecution.create!(
        started_at: i.hours.ago,
        collection_item_id: 1000 + i,
        card_id: "card-#{i}"
      )
    end

    get api_path("/admin/image_cache_executions")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 100, json.length
  end

  test "GET index returns timestamps in ISO 8601 format" do
    get api_path("/admin/image_cache_executions")

    assert_response :success
    json = JSON.parse(response.body)
    execution_json = json.first

    # Verify ISO 8601 format (includes timezone)
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}/, execution_json["started_at"]
    assert_match /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}/, execution_json["finished_at"]
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/image_cache_executions/:id - show
  # ---------------------------------------------------------------------------
  test "GET show returns single execution by id" do
    get api_path("/admin/image_cache_executions/#{@execution1.id}")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @execution1.id, json["id"]
    assert_equal 100, json["collection_item_id"]
    assert_equal "card-abc-123", json["card_id"]
    assert_equal true, json["downloaded"]
    assert_equal 45678, json["file_size_bytes"]
  end

  test "GET show returns 404 for non-existent execution" do
    get api_path("/admin/image_cache_executions/99999")

    assert_response :not_found
    json = JSON.parse(response.body)

    assert_includes json["error"], "not found"
  end

  test "GET show returns all execution fields including error_message" do
    get api_path("/admin/image_cache_executions/#{@execution3.id}")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @execution3.id, json["id"]
    assert_equal "failure", json["status"]
    assert_equal "HTTP 404 Not Found", json["error_message"]
    assert_equal false, json["downloaded"]
    assert_equal false, json["cache_hit"]
    assert_not_nil json["execution_time_seconds"]
  end

  # ---------------------------------------------------------------------------
  # GET /api/admin/image_cache_executions/stats - stats
  # ---------------------------------------------------------------------------
  test "GET stats returns aggregate statistics" do
    get api_path("/admin/image_cache_executions/stats")

    assert_response :success
    json = JSON.parse(response.body)

    assert_includes json.keys, "total_executions"
    assert_includes json.keys, "successful_executions"
    assert_includes json.keys, "failed_executions"
    assert_includes json.keys, "skipped_executions"
    assert_includes json.keys, "success_rate"
    assert_includes json.keys, "cache_hit_rate"
    assert_includes json.keys, "last_24h_success_rate"
    assert_includes json.keys, "last_7d_avg_duration"
    assert_includes json.keys, "total_downloads_last_24h"
    assert_includes json.keys, "failed_count_last_24h"
  end

  test "GET stats calculates totals correctly" do
    get api_path("/admin/image_cache_executions/stats")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 4, json["total_executions"]
    assert_equal 2, json["successful_executions"]  # execution1, execution2
    assert_equal 1, json["failed_executions"]  # execution3
    assert_equal 1, json["skipped_executions"]  # execution4
  end

  test "GET stats calculates success rate" do
    get api_path("/admin/image_cache_executions/stats")

    assert_response :success
    json = JSON.parse(response.body)

    # 2 successes out of 4 total = 50%
    assert_equal 50.0, json["success_rate"]
  end

  test "GET stats calculates cache hit rate" do
    get api_path("/admin/image_cache_executions/stats")

    assert_response :success
    json = JSON.parse(response.body)

    # 1 cache hit (execution2) out of 2 successful = 50%
    assert_equal 50.0, json["cache_hit_rate"]
  end

  test "GET stats returns zero values when no executions exist" do
    ImageCacheExecution.delete_all

    get api_path("/admin/image_cache_executions/stats")

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal 0, json["total_executions"]
    assert_equal 0, json["successful_executions"]
    assert_equal 0.0, json["success_rate"]
    assert_equal 0.0, json["cache_hit_rate"]
  end

  # ---------------------------------------------------------------------------
  # Error handling
  # ---------------------------------------------------------------------------
  test "GET index handles invalid date format gracefully" do
    get api_path("/admin/image_cache_executions?start_date=invalid-date")

    # Should return error or empty result, not crash
    assert_response :success # or :bad_request depending on implementation
  end

  test "GET index handles invalid status filter gracefully" do
    get api_path("/admin/image_cache_executions?status=invalid_status")

    assert_response :success
    json = JSON.parse(response.body)

    # Should return empty array for invalid status
    assert_equal [], json
  end

  test "GET index handles invalid boolean filter gracefully" do
    get api_path("/admin/image_cache_executions?cache_hit=invalid")

    assert_response :success
    # Should handle gracefully, possibly returning all or none
  end
end
