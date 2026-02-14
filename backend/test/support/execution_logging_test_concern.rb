# Shared test concern for execution logging behavior
#
# This module provides common test assertions for jobs that implement execution logging.
# Jobs must implement the following interface for these tests to work:
#
# Required methods to override in the test class:
#   - perform_job: Execute the job with appropriate parameters
#   - execution_model: Return the execution model class (e.g., ScraperExecution)
#   - job_class: Return the job class being tested (e.g., ScrapeEdhrecCommandersJob)
#   - job_component_name: Return the component name used in logs (e.g., "ScrapeEdhrecCommandersJob")
#   - stub_success: Stub external dependencies for successful execution
#   - stub_error(error): Stub external dependencies to raise the given error
#
# Optional methods to override:
#   - setup_execution_logging_test: Additional setup for each test (called in setup)
#   - teardown_execution_logging_test: Additional teardown for each test (called in teardown)
#
# Usage example:
#   class MyJobExecutionLoggingTest < ActiveJob::TestCase
#     include ExecutionLoggingTestConcern
#
#     def perform_job
#       MyJob.perform_now(arg1, arg2)
#     end
#
#     def execution_model
#       MyExecution
#     end
#
#     def job_class
#       MyJob
#     end
#
#     def job_component_name
#       "MyJob"
#     end
#
#     def stub_success
#       # Stub external dependencies
#       yield
#     end
#
#     def stub_error(error)
#       # Stub external dependencies to raise error
#       yield
#     end
#   end

module ExecutionLoggingTestConcern
  extend ActiveSupport::Concern

  included do
    setup do
      setup_logging_capture
      setup_execution_logging_test if respond_to?(:setup_execution_logging_test)
    end

    teardown do
      restore_logging
      teardown_execution_logging_test if respond_to?(:teardown_execution_logging_test)
    end
  end

  # ---------------------------------------------------------------------------
  # Execution record creation tests
  # ---------------------------------------------------------------------------

  def test_creates_execution_record_with_started_at
    stub_success do
      assert_difference "#{execution_model}.count", 1 do
        perform_job
      end

      execution = execution_model.last
      assert_not_nil execution.started_at, "Execution record should have started_at timestamp"
      assert execution.started_at <= Time.current, "started_at should not be in the future"
    end
  end

  def test_sets_finished_at_when_completed
    stub_success do
      perform_job

      execution = execution_model.last
      assert_not_nil execution.finished_at, "Execution record should have finished_at timestamp"
      assert execution.finished_at >= execution.started_at, "finished_at should be after started_at"
      assert execution.execution_time_seconds.positive?, "Execution time should be positive"
    end
  end

  def test_records_success_status_on_successful_execution
    stub_success do
      perform_job

      execution = execution_model.last
      assert_equal "success", execution.status, "Status should be 'success' for successful execution"
    end
  end

  # ---------------------------------------------------------------------------
  # Structured JSON logging tests
  # ---------------------------------------------------------------------------

  def test_logs_started_event_in_json_format
    stub_success do
      perform_job

      log_content = @log_output.string
      assert_match /"event":"[^"]*started"/, log_content, "Should log a 'started' event"
      assert_match /"component":"#{job_component_name}"/, log_content, "Should log component name"
      assert_match /"timestamp":"#{Time.current.year}/, log_content, "Should log current year in timestamp"
    end
  end

  def test_logs_completed_event_with_summary
    stub_success do
      perform_job

      log_content = @log_output.string
      assert_match /"event":"[^"]*completed"/, log_content, "Should log a 'completed' event"
      assert_match /"status":"success"/, log_content, "Should log success status"
      assert_match /"duration_seconds":/, log_content, "Should log execution duration"
    end
  end

  # ---------------------------------------------------------------------------
  # Error logging tests
  # ---------------------------------------------------------------------------

  def test_logs_error_with_full_context_when_error_occurs
    # Skip this test if the job doesn't raise exceptions (e.g., non-blocking jobs)
    skip "Job does not raise exceptions on error" if respond_to?(:job_raises_on_error?) && !job_raises_on_error?

    test_error = StandardError.new("Test error message")

    stub_error(test_error) do
      assert_raises(StandardError) do
        perform_job
      end

      log_content = @log_output.string
      assert_match /"event":"error_occurred"/, log_content, "Should log error_occurred event"
      assert_match /"error_class":"StandardError"/, log_content, "Should log error class"
      assert_match /"error_message":"Test error message"/, log_content, "Should log error message"
      assert_match /"component":"#{job_component_name}"/, log_content, "Should log component name in error"
    end
  end

  def test_records_failure_status_when_error_occurs
    # Skip this test if the job doesn't raise exceptions (e.g., non-blocking jobs)
    skip "Job does not raise exceptions on error" if respond_to?(:job_raises_on_error?) && !job_raises_on_error?

    test_error = StandardError.new("Test failure")

    stub_error(test_error) do
      assert_raises(StandardError) do
        perform_job
      end

      execution = execution_model.last
      assert_equal "failure", execution.status, "Status should be 'failure' when error occurs"
      assert_not_nil execution.error_summary, "Should record error summary"
    end
  end

  # ---------------------------------------------------------------------------
  # Sensitive data redaction tests
  # ---------------------------------------------------------------------------

  def test_does_not_log_sensitive_credentials
    # Skip this test if the job doesn't raise exceptions (e.g., non-blocking jobs)
    skip "Job does not raise exceptions on error" if respond_to?(:job_raises_on_error?) && !job_raises_on_error?

    original_key = ENV["SCRYFALL_API_KEY"]
    ENV["SCRYFALL_API_KEY"] = "secret_api_key_12345"

    error_with_secret = StandardError.new("Error with SCRYFALL_API_KEY=secret_api_key_12345")
    stub_error(error_with_secret) do
      assert_raises(StandardError) do
        perform_job
      end

      log_content = @log_output.string
      assert_no_match /secret_api_key_12345/, log_content, "Should not log sensitive API keys"
      assert_match /\[REDACTED\]/, log_content, "Should redact sensitive data"
    end
  ensure
    ENV["SCRYFALL_API_KEY"] = original_key
  end

  # ---------------------------------------------------------------------------
  # ISO 8601 timestamp format tests
  # ---------------------------------------------------------------------------

  def test_logs_timestamps_in_iso_8601_format
    stub_success do
      perform_job

      log_content = @log_output.string
      # ISO 8601 format: 2026-02-08T10:30:45Z or 2026-02-08T10:30:45+00:00
      assert_match /"timestamp":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, log_content,
                   "Timestamps should be in ISO 8601 format"
    end
  end

  # ---------------------------------------------------------------------------
  # Log level tests
  # ---------------------------------------------------------------------------

  def test_uses_info_log_level_for_normal_operations
    stub_success do
      perform_job

      log_content = @log_output.string
      assert_match /"level":"INFO"/, log_content, "Should use INFO level for normal operations"
    end
  end

  private

  # ---------------------------------------------------------------------------
  # Helper methods for logging capture
  # ---------------------------------------------------------------------------

  def setup_logging_capture
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = Logger.new(@log_output)
    Rails.logger.level = Logger::INFO
  end

  def restore_logging
    Rails.logger = @original_logger
  end
end
