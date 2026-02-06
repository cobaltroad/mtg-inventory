require "test_helper"
require "yaml"

class RecurringJobsTest < ActiveSupport::TestCase
  test "daily card price update job is configured in recurring.yml" do
    recurring_config = YAML.load_file(Rails.root.join("config/recurring.yml"))

    # Check production configuration
    assert recurring_config["production"], "Production configuration should exist"
    assert recurring_config["production"]["daily_card_price_update"],
      "daily_card_price_update job should be configured"

    job_config = recurring_config["production"]["daily_card_price_update"]

    # Verify job configuration
    assert_equal "UpdateCardPricesJob", job_config["class"],
      "Job class should be UpdateCardPricesJob"
    assert_equal "default", job_config["queue"],
      "Job should use default queue"
    assert_equal "every day at 2am", job_config["schedule"],
      "Job should run daily at 2am"
    assert_equal [], job_config["args"],
      "Job should be called without arguments for batch mode"
  end
end
