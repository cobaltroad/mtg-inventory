require "test_helper"
require "rake"

class PricesRakeTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Clear task to allow re-running
    Rake::Task["prices:update"].reenable
  end

  test "prices:update task exists" do
    assert Rake::Task["prices:update"]
  end

  test "prices:update task has description" do
    task = Rake::Task["prices:update"]
    assert_not_nil task.full_comment
    assert_includes task.full_comment.downcase, "update prices"
  end

  test "prices:update enqueues job when cards exist" do
    # Create a collection item
    user = users(:one)
    CollectionItem.create!(
      user: user,
      card_id: "test-card-123",
      quantity: 1,
      collection_type: "inventory"
    )

    # Stub perform_now to avoid actual execution
    UpdateCardPricesJob.stub :perform_now, nil do
      # Capture output
      output = capture_io do
        Rake::Task["prices:update"].invoke
      end

      assert_includes output.join, "Starting manual price update"
      assert_includes output.join, "1 unique cards to process"
    end
  end

  test "prices:update handles empty inventory gracefully" do
    # Ensure no collection items exist
    CollectionItem.delete_all

    output = capture_io do
      Rake::Task["prices:update"].invoke
    end

    assert_includes output.join, "No cards found"
  end

  private

  def capture_io
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new

    yield

    [ $stdout.string, $stderr.string ]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end
end
