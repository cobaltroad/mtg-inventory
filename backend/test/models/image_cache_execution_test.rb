require "test_helper"

class ImageCacheExecutionTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      status: :success,
      collection_item_id: 1,
      card_id: "abc123",
      cache_hit: false,
      downloaded: true,
      file_size_bytes: 45678
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  test "is invalid without started_at" do
    execution = ImageCacheExecution.new(
      started_at: nil,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert execution.invalid?
    assert_includes execution.errors[:started_at], "can't be blank"
  end

  test "is invalid without collection_item_id" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: nil,
      card_id: "abc123"
    )
    assert execution.invalid?
    assert_includes execution.errors[:collection_item_id], "can't be blank"
  end

  test "is invalid without card_id" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: nil
    )
    assert execution.invalid?
    assert_includes execution.errors[:card_id], "can't be blank"
  end

  test "is valid with minimal required attributes" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Enum status values
  # ---------------------------------------------------------------------------
  test "status defaults to success" do
    execution = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert_equal "success", execution.status
  end

  test "accepts success status" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      status: :success
    )
    assert execution.valid?
    assert_equal "success", execution.status
  end

  test "accepts failure status" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      status: :failure
    )
    assert execution.valid?
    assert_equal "failure", execution.status
  end

  test "accepts skipped status" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      status: :skipped
    )
    assert execution.valid?
    assert_equal "skipped", execution.status
  end

  test "rejects invalid status" do
    assert_raises(ArgumentError) do
      ImageCacheExecution.new(
        started_at: Time.current,
        collection_item_id: 1,
        card_id: "abc123",
        status: :invalid_status
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Boolean flags default values
  # ---------------------------------------------------------------------------
  test "cache_hit defaults to false" do
    execution = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert_equal false, execution.cache_hit
  end

  test "downloaded defaults to false" do
    execution = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert_equal false, execution.downloaded
  end

  test "can set cache_hit to true" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      cache_hit: true
    )
    assert execution.valid?
    assert_equal true, execution.cache_hit
  end

  test "can set downloaded to true" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      downloaded: true
    )
    assert execution.valid?
    assert_equal true, execution.downloaded
  end

  # ---------------------------------------------------------------------------
  # Numericality validations
  # ---------------------------------------------------------------------------
  test "is invalid when file_size_bytes is negative" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      file_size_bytes: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:file_size_bytes], "must be greater than or equal to 0"
  end

  test "is valid when file_size_bytes is zero" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      file_size_bytes: 0
    )
    assert execution.valid?
  end

  test "is valid when file_size_bytes is nil" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      file_size_bytes: nil
    )
    assert execution.valid?
  end

  # ---------------------------------------------------------------------------
  # Calculated method: execution_time_seconds
  # ---------------------------------------------------------------------------
  test "execution_time_seconds returns nil when finished_at is nil" do
    execution = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert_nil execution.execution_time_seconds
  end

  test "execution_time_seconds calculates duration when both timestamps present" do
    started = Time.zone.parse("2026-02-08 10:00:00")
    finished = Time.zone.parse("2026-02-08 10:00:05")

    execution = ImageCacheExecution.create!(
      started_at: started,
      finished_at: finished,
      collection_item_id: 1,
      card_id: "abc123"
    )

    assert_equal 5.0, execution.execution_time_seconds
  end

  test "execution_time_seconds returns float with decimal precision" do
    started = Time.zone.parse("2026-02-08 10:00:00.000")
    finished = Time.zone.parse("2026-02-08 10:00:00.250")

    execution = ImageCacheExecution.create!(
      started_at: started,
      finished_at: finished,
      collection_item_id: 1,
      card_id: "abc123"
    )

    assert_equal 0.25, execution.execution_time_seconds
  end

  # ---------------------------------------------------------------------------
  # Optional fields
  # ---------------------------------------------------------------------------
  test "is valid with error_message" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      error_message: "Failed to download image: HTTP 404 Not Found"
    )
    assert execution.valid?
  end

  test "is valid without error_message" do
    execution = ImageCacheExecution.new(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      error_message: nil
    )
    assert execution.valid?
  end

  test "is valid with finished_at" do
    execution = ImageCacheExecution.new(
      started_at: Time.current - 1.second,
      finished_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123"
    )
    assert execution.valid?
  end

  # ---------------------------------------------------------------------------
  # Database constraints and indexes
  # ---------------------------------------------------------------------------
  test "has index on started_at for performance" do
    indexes = ActiveRecord::Base.connection.indexes(:image_cache_executions)
    started_at_index = indexes.find { |idx| idx.columns == [ "started_at" ] }
    assert_not_nil started_at_index, "started_at index should exist"
  end

  test "has index on status for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:image_cache_executions)
    status_index = indexes.find { |idx| idx.columns == [ "status" ] }
    assert_not_nil status_index, "status index should exist"
  end

  test "has index on collection_item_id for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:image_cache_executions)
    collection_item_index = indexes.find { |idx| idx.columns == [ "collection_item_id" ] }
    assert_not_nil collection_item_index, "collection_item_id index should exist"
  end

  test "has index on card_id for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:image_cache_executions)
    card_id_index = indexes.find { |idx| idx.columns == [ "card_id" ] }
    assert_not_nil card_id_index, "card_id index should exist"
  end

  # ---------------------------------------------------------------------------
  # Ordering and querying
  # ---------------------------------------------------------------------------
  test "can order by most recent first" do
    old_execution = ImageCacheExecution.create!(
      started_at: 2.days.ago,
      collection_item_id: 1,
      card_id: "old123"
    )
    recent_execution = ImageCacheExecution.create!(
      started_at: 1.hour.ago,
      collection_item_id: 2,
      card_id: "recent456"
    )

    results = ImageCacheExecution.order(started_at: :desc)
    assert_equal recent_execution.id, results.first.id
    assert_equal old_execution.id, results.last.id
  end

  test "can filter by status" do
    success = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      status: :success
    )
    failure = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 2,
      card_id: "def456",
      status: :failure
    )

    successes = ImageCacheExecution.where(status: :success)
    assert_includes successes, success
    assert_not_includes successes, failure
  end

  test "can filter by card_id" do
    card1 = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "card_a"
    )
    card2 = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 2,
      card_id: "card_b"
    )

    card_a_executions = ImageCacheExecution.where(card_id: "card_a")
    assert_includes card_a_executions, card1
    assert_not_includes card_a_executions, card2
  end

  test "can filter by collection_item_id" do
    item1 = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 100,
      card_id: "abc"
    )
    item2 = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 200,
      card_id: "def"
    )

    item_100_executions = ImageCacheExecution.where(collection_item_id: 100)
    assert_includes item_100_executions, item1
    assert_not_includes item_100_executions, item2
  end

  test "can filter by cache_hit" do
    hit = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 1,
      card_id: "abc123",
      cache_hit: true
    )
    miss = ImageCacheExecution.create!(
      started_at: Time.current,
      collection_item_id: 2,
      card_id: "def456",
      cache_hit: false
    )

    cache_hits = ImageCacheExecution.where(cache_hit: true)
    assert_includes cache_hits, hit
    assert_not_includes cache_hits, miss
  end
end
