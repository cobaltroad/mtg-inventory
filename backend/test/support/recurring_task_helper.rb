# frozen_string_literal: true

# Helper module for loading recurring tasks in tests.
# Solid Queue's recurring scheduler loads tasks from recurring.yml at startup,
# but this doesn't happen during test runs. This module provides a helper to
# manually load recurring tasks for testing purposes.
module RecurringTaskHelper
  # Load recurring tasks from recurring.yml into the test database
  def load_recurring_tasks_from_config
    recurring_config_path = Rails.root.join("config/recurring.yml")
    return unless File.exist?(recurring_config_path)

    recurring_config = YAML.load_file(recurring_config_path)
    env_config = recurring_config[Rails.env.to_s] || {}

    # Clear existing tasks to ensure clean state
    SolidQueue::RecurringTask.delete_all

    # Create recurring task records for current environment
    env_config.each do |key, config|
      SolidQueue::RecurringTask.create!(
        key: key,
        class_name: config["class"],
        schedule: config["schedule"],
        queue_name: config["queue"] || "default",
        arguments: config["args"] || []
      )
    end
  end
end
