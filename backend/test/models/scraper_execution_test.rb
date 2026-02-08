require "test_helper"

class ScraperExecutionTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      status: :success,
      commanders_attempted: 20,
      commanders_succeeded: 20,
      commanders_failed: 0,
      total_cards_processed: 2000
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  test "is invalid without started_at" do
    execution = ScraperExecution.new(
      started_at: nil,
      status: :success
    )
    assert execution.invalid?
    assert_includes execution.errors[:started_at], "can't be blank"
  end

  test "is valid with minimal attributes (started_at only)" do
    execution = ScraperExecution.new(
      started_at: Time.current
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Enum status values
  # ---------------------------------------------------------------------------
  test "status defaults to success" do
    execution = ScraperExecution.create!(started_at: Time.current)
    assert_equal "success", execution.status
  end

  test "accepts success status" do
    execution = ScraperExecution.new(started_at: Time.current, status: :success)
    assert execution.valid?
    assert_equal "success", execution.status
  end

  test "accepts partial_success status" do
    execution = ScraperExecution.new(started_at: Time.current, status: :partial_success)
    assert execution.valid?
    assert_equal "partial_success", execution.status
  end

  test "accepts failure status" do
    execution = ScraperExecution.new(started_at: Time.current, status: :failure)
    assert execution.valid?
    assert_equal "failure", execution.status
  end

  test "rejects invalid status" do
    assert_raises(ArgumentError) do
      ScraperExecution.new(started_at: Time.current, status: :invalid_status)
    end
  end

  # ---------------------------------------------------------------------------
  # Numericality validations for counter fields
  # ---------------------------------------------------------------------------
  test "is invalid when commanders_attempted is negative" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      commanders_attempted: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:commanders_attempted], "must be greater than or equal to 0"
  end

  test "is valid when commanders_attempted is zero" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      commanders_attempted: 0
    )
    assert execution.valid?
  end

  test "is invalid when commanders_succeeded is negative" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      commanders_succeeded: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:commanders_succeeded], "must be greater than or equal to 0"
  end

  test "is invalid when commanders_failed is negative" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      commanders_failed: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:commanders_failed], "must be greater than or equal to 0"
  end

  test "is invalid when total_cards_processed is negative" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      total_cards_processed: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:total_cards_processed], "must be greater than or equal to 0"
  end

  test "defaults counter fields to zero" do
    execution = ScraperExecution.create!(started_at: Time.current)
    assert_equal 0, execution.commanders_attempted
    assert_equal 0, execution.commanders_succeeded
    assert_equal 0, execution.commanders_failed
    assert_equal 0, execution.total_cards_processed
  end

  # ---------------------------------------------------------------------------
  # Calculated method: execution_time_seconds
  # ---------------------------------------------------------------------------
  test "execution_time_seconds returns nil when finished_at is nil" do
    execution = ScraperExecution.create!(
      started_at: Time.current
    )
    assert_nil execution.execution_time_seconds
  end

  test "execution_time_seconds calculates duration when both timestamps present" do
    started = Time.zone.parse("2026-02-08 10:00:00")
    finished = Time.zone.parse("2026-02-08 10:05:30")

    execution = ScraperExecution.create!(
      started_at: started,
      finished_at: finished
    )

    assert_equal 330.0, execution.execution_time_seconds
  end

  test "execution_time_seconds returns float with decimal precision" do
    started = Time.zone.parse("2026-02-08 10:00:00.000")
    finished = Time.zone.parse("2026-02-08 10:00:01.500")

    execution = ScraperExecution.create!(
      started_at: started,
      finished_at: finished
    )

    assert_equal 1.5, execution.execution_time_seconds
  end

  # ---------------------------------------------------------------------------
  # Calculated method: success_rate
  # ---------------------------------------------------------------------------
  test "success_rate returns 0 when commanders_attempted is zero" do
    execution = ScraperExecution.create!(
      started_at: Time.current,
      commanders_attempted: 0,
      commanders_succeeded: 0
    )
    assert_equal 0, execution.success_rate
  end

  test "success_rate returns 100 when all commanders succeeded" do
    execution = ScraperExecution.create!(
      started_at: Time.current,
      commanders_attempted: 20,
      commanders_succeeded: 20
    )
    assert_equal 100.0, execution.success_rate
  end

  test "success_rate returns 0 when no commanders succeeded" do
    execution = ScraperExecution.create!(
      started_at: Time.current,
      commanders_attempted: 20,
      commanders_succeeded: 0
    )
    assert_equal 0.0, execution.success_rate
  end

  test "success_rate calculates percentage correctly for partial success" do
    execution = ScraperExecution.create!(
      started_at: Time.current,
      commanders_attempted: 20,
      commanders_succeeded: 15
    )
    assert_equal 75.0, execution.success_rate
  end

  test "success_rate rounds to 2 decimal places" do
    execution = ScraperExecution.create!(
      started_at: Time.current,
      commanders_attempted: 3,
      commanders_succeeded: 2
    )
    assert_equal 66.67, execution.success_rate
  end

  # ---------------------------------------------------------------------------
  # Optional fields
  # ---------------------------------------------------------------------------
  test "is valid with error_summary" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      error_summary: "Failed to connect to EDHREC: Connection timeout after 30s"
    )
    assert execution.valid?
  end

  test "is valid without error_summary" do
    execution = ScraperExecution.new(
      started_at: Time.current,
      error_summary: nil
    )
    assert execution.valid?
  end

  test "is valid with finished_at" do
    execution = ScraperExecution.new(
      started_at: Time.current - 1.hour,
      finished_at: Time.current
    )
    assert execution.valid?
  end

  # ---------------------------------------------------------------------------
  # Database constraints and indexes
  # ---------------------------------------------------------------------------
  test "has index on started_at for performance" do
    indexes = ActiveRecord::Base.connection.indexes(:scraper_executions)
    started_at_index = indexes.find { |idx| idx.columns == [ "started_at" ] }
    assert_not_nil started_at_index, "started_at index should exist"
  end

  test "has index on status for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:scraper_executions)
    status_index = indexes.find { |idx| idx.columns == [ "status" ] }
    assert_not_nil status_index, "status index should exist"
  end

  # ---------------------------------------------------------------------------
  # Ordering and querying
  # ---------------------------------------------------------------------------
  test "can order by most recent first" do
    old_execution = ScraperExecution.create!(
      started_at: 2.days.ago
    )
    recent_execution = ScraperExecution.create!(
      started_at: 1.hour.ago
    )

    results = ScraperExecution.order(started_at: :desc)
    assert_equal recent_execution.id, results.first.id
    assert_equal old_execution.id, results.last.id
  end

  test "can filter by status" do
    success = ScraperExecution.create!(
      started_at: Time.current,
      status: :success
    )
    failure = ScraperExecution.create!(
      started_at: Time.current,
      status: :failure
    )

    successes = ScraperExecution.where(status: :success)
    assert_includes successes, success
    assert_not_includes successes, failure
  end
end
