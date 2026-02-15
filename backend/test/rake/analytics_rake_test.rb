require "test_helper"
require "rake"

class AnalyticsRakeTest < ActiveSupport::TestCase
  def setup
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Clear existing task
    Rake::Task["analytics:consolidate_edhrec"].reenable

    # Create test data
    @commander = Commander.create!(
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/test"
    )

    Decklist.create!(
      commander: @commander,
      partner: nil,
      contents: [
        {
          card_id: "rare-test-1",
          card_name: "Rare Test Card",
          rarity: "rare",
          edh_rank: 100,
          quantity: 1
        },
        {
          card_id: "mythic-test-1",
          card_name: "Mythic Test Card",
          rarity: "mythic",
          edh_rank: 50,
          quantity: 1
        }
      ]
    )
  end

  test "consolidate_edhrec task enqueues job and shows summary" do
    # Capture output
    output = capture_io do
      Rake::Task["analytics:consolidate_edhrec"].invoke
    end.join

    # Verify output contains expected information
    assert_match(/Consolidating EDHREC Analytics/, output)
    assert_match(/Consolidation Complete/, output)
    assert_match(/Total unique cards: 2/, output)
    assert_match(/Rare cards: 1/, output)
    assert_match(/Mythic cards: 1/, output)
    assert_match(/Rare Test Card/, output)
    assert_match(/Mythic Test Card/, output)

    # Verify records were created
    assert_equal 2, CardAnalytic.for_source("edhrec").count
  end

  test "consolidate_edhrec task is idempotent" do
    # Run twice
    capture_io { Rake::Task["analytics:consolidate_edhrec"].invoke }
    Rake::Task["analytics:consolidate_edhrec"].reenable
    capture_io { Rake::Task["analytics:consolidate_edhrec"].invoke }

    # Should still have same count
    assert_equal 2, CardAnalytic.for_source("edhrec").count
  end
end
