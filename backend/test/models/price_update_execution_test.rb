require "test_helper"

class PriceUpdateExecutionTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      status: :success,
      mode: "batch",
      cards_attempted: 100,
      cards_succeeded: 95,
      cards_failed: 3,
      cards_skipped: 2,
      price_alerts_created: 5
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  test "is invalid without started_at" do
    execution = PriceUpdateExecution.new(
      started_at: nil,
      status: :success,
      mode: "batch"
    )
    assert execution.invalid?
    assert_includes execution.errors[:started_at], "can't be blank"
  end

  test "is invalid without mode" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: nil
    )
    assert execution.invalid?
    assert_includes execution.errors[:mode], "can't be blank"
  end

  test "is valid with minimal attributes (started_at and mode only)" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch"
    )
    assert execution.valid?, execution.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Enum status values
  # ---------------------------------------------------------------------------
  test "status defaults to success" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch"
    )
    assert_equal "success", execution.status
  end

  test "accepts success status" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      status: :success
    )
    assert execution.valid?
    assert_equal "success", execution.status
  end

  test "accepts partial_success status" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      status: :partial_success
    )
    assert execution.valid?
    assert_equal "partial_success", execution.status
  end

  test "accepts failure status" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      status: :failure
    )
    assert execution.valid?
    assert_equal "failure", execution.status
  end

  test "rejects invalid status" do
    assert_raises(ArgumentError) do
      PriceUpdateExecution.new(
        started_at: Time.current,
        mode: "batch",
        status: :invalid_status
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Mode validation
  # ---------------------------------------------------------------------------
  test "accepts batch mode" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch"
    )
    assert execution.valid?
  end

  test "accepts single_card mode" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "single_card"
    )
    assert execution.valid?
  end

  # ---------------------------------------------------------------------------
  # Numericality validations for counter fields
  # ---------------------------------------------------------------------------
  test "is invalid when cards_attempted is negative" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:cards_attempted], "must be greater than or equal to 0"
  end

  test "is valid when cards_attempted is zero" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 0
    )
    assert execution.valid?
  end

  test "is invalid when cards_succeeded is negative" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      cards_succeeded: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:cards_succeeded], "must be greater than or equal to 0"
  end

  test "is invalid when cards_failed is negative" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      cards_failed: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:cards_failed], "must be greater than or equal to 0"
  end

  test "is invalid when cards_skipped is negative" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      cards_skipped: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:cards_skipped], "must be greater than or equal to 0"
  end

  test "is invalid when price_alerts_created is negative" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      price_alerts_created: -1
    )
    assert execution.invalid?
    assert_includes execution.errors[:price_alerts_created], "must be greater than or equal to 0"
  end

  test "defaults counter fields to zero" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch"
    )
    assert_equal 0, execution.cards_attempted
    assert_equal 0, execution.cards_succeeded
    assert_equal 0, execution.cards_failed
    assert_equal 0, execution.cards_skipped
    assert_equal 0, execution.price_alerts_created
  end

  # ---------------------------------------------------------------------------
  # Calculated method: execution_time_seconds
  # ---------------------------------------------------------------------------
  test "execution_time_seconds returns nil when finished_at is nil" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch"
    )
    assert_nil execution.execution_time_seconds
  end

  test "execution_time_seconds calculates duration when both timestamps present" do
    started = Time.zone.parse("2026-02-08 10:00:00")
    finished = Time.zone.parse("2026-02-08 10:05:30")

    execution = PriceUpdateExecution.create!(
      started_at: started,
      finished_at: finished,
      mode: "batch"
    )

    assert_equal 330.0, execution.execution_time_seconds
  end

  test "execution_time_seconds returns float with decimal precision" do
    started = Time.zone.parse("2026-02-08 10:00:00.000")
    finished = Time.zone.parse("2026-02-08 10:00:01.500")

    execution = PriceUpdateExecution.create!(
      started_at: started,
      finished_at: finished,
      mode: "batch"
    )

    assert_equal 1.5, execution.execution_time_seconds
  end

  # ---------------------------------------------------------------------------
  # Calculated method: success_rate
  # ---------------------------------------------------------------------------
  test "success_rate returns 0 when cards_attempted is zero" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 0,
      cards_succeeded: 0
    )
    assert_equal 0, execution.success_rate
  end

  test "success_rate returns 100 when all cards succeeded" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 100,
      cards_succeeded: 100
    )
    assert_equal 100.0, execution.success_rate
  end

  test "success_rate returns 0 when no cards succeeded" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 100,
      cards_succeeded: 0
    )
    assert_equal 0.0, execution.success_rate
  end

  test "success_rate calculates percentage correctly for partial success" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 100,
      cards_succeeded: 75
    )
    assert_equal 75.0, execution.success_rate
  end

  test "success_rate rounds to 2 decimal places" do
    execution = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      cards_attempted: 3,
      cards_succeeded: 2
    )
    assert_equal 66.67, execution.success_rate
  end

  # ---------------------------------------------------------------------------
  # Optional fields
  # ---------------------------------------------------------------------------
  test "is valid with error_summary" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      error_summary: "Failed to connect to Scryfall: Connection timeout after 30s"
    )
    assert execution.valid?
  end

  test "is valid without error_summary" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current,
      mode: "batch",
      error_summary: nil
    )
    assert execution.valid?
  end

  test "is valid with finished_at" do
    execution = PriceUpdateExecution.new(
      started_at: Time.current - 1.hour,
      finished_at: Time.current,
      mode: "batch"
    )
    assert execution.valid?
  end

  # ---------------------------------------------------------------------------
  # Database constraints and indexes
  # ---------------------------------------------------------------------------
  test "has index on started_at for performance" do
    indexes = ActiveRecord::Base.connection.indexes(:price_update_executions)
    started_at_index = indexes.find { |idx| idx.columns == [ "started_at" ] }
    assert_not_nil started_at_index, "started_at index should exist"
  end

  test "has index on status for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:price_update_executions)
    status_index = indexes.find { |idx| idx.columns == [ "status" ] }
    assert_not_nil status_index, "status index should exist"
  end

  test "has index on mode for filtering" do
    indexes = ActiveRecord::Base.connection.indexes(:price_update_executions)
    mode_index = indexes.find { |idx| idx.columns == [ "mode" ] }
    assert_not_nil mode_index, "mode index should exist"
  end

  # ---------------------------------------------------------------------------
  # Ordering and querying
  # ---------------------------------------------------------------------------
  test "can order by most recent first" do
    old_execution = PriceUpdateExecution.create!(
      started_at: 2.days.ago,
      mode: "batch"
    )
    recent_execution = PriceUpdateExecution.create!(
      started_at: 1.hour.ago,
      mode: "batch"
    )

    results = PriceUpdateExecution.order(started_at: :desc)
    assert_equal recent_execution.id, results.first.id
    assert_equal old_execution.id, results.last.id
  end

  test "can filter by status" do
    success = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      status: :success
    )
    failure = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch",
      status: :failure
    )

    successes = PriceUpdateExecution.where(status: :success)
    assert_includes successes, success
    assert_not_includes successes, failure
  end

  test "can filter by mode" do
    batch = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "batch"
    )
    single = PriceUpdateExecution.create!(
      started_at: Time.current,
      mode: "single_card"
    )

    batch_executions = PriceUpdateExecution.where(mode: "batch")
    assert_includes batch_executions, batch
    assert_not_includes batch_executions, single
  end
end
