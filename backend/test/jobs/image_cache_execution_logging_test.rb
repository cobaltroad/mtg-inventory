require "test_helper"
require "webmock/minitest"

class ImageCacheExecutionLoggingTest < ActiveJob::TestCase
  setup do
    # Disable VCR for these tests since we're using WebMock stubs directly
    VCR.turn_off!(ignore_cassettes: true)
    WebMock.enable!

    # Clear any existing data in proper order (dependencies first)
    ImageCacheExecution.delete_all
    CollectionItem.delete_all
    User.delete_all

    # Create test user and collection item
    @user = User.create!(
      email: "test@example.com",
      name: "Test User"
    )
    @item = CollectionItem.create!(
      user: @user,
      collection_type: "inventory",
      card_id: "test-card-123",
      quantity: 1
    )
    @image_url = "https://cards.scryfall.io/normal/front/test.jpg"

    # Capture logs for assertions
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = Logger.new(@log_output)
    Rails.logger.level = Logger::INFO
  end

  teardown do
    # Restore original logger
    Rails.logger = @original_logger

    # Re-enable VCR
    VCR.turn_on!
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Execution record creation
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob creates execution record with started_at" do
    stub_image_cache_service_success do
      assert_difference "ImageCacheExecution.count", 1 do
        CacheCardImageJob.perform_now(@item.id, @image_url)
      end

      execution = ImageCacheExecution.last
      assert_not_nil execution.started_at
      assert execution.started_at <= Time.current
      assert_equal @item.id, execution.collection_item_id
      assert_equal @item.card_id, execution.card_id
    end
  end

  test "CacheCardImageJob sets finished_at when completed" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
      assert_not_nil execution.finished_at
      assert execution.finished_at >= execution.started_at
      assert execution.execution_time_seconds.positive?
    end
  end

  test "CacheCardImageJob records success status when image downloaded" do
    stub_image_cache_service_success(downloaded: true, file_size: 45678) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
      assert_equal "success", execution.status
      assert_equal true, execution.downloaded
      assert_equal false, execution.cache_hit
      assert_equal 45678, execution.file_size_bytes
    end
  end

  test "CacheCardImageJob records cache_hit when image already cached" do
    stub_image_cache_service_success(cached: true, downloaded: false) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
      assert_equal "success", execution.status
      assert_equal true, execution.cache_hit
      assert_equal false, execution.downloaded
      assert_nil execution.file_size_bytes
    end
  end

  test "CacheCardImageJob records skipped status when collection item not found" do
    invalid_item_id = 99999

    assert_difference "ImageCacheExecution.count", 1 do
      CacheCardImageJob.perform_now(invalid_item_id, @image_url)
    end

    execution = ImageCacheExecution.last
    assert_equal "skipped", execution.status
    assert_not_nil execution.error_message
    assert_match /not found/i, execution.error_message
  end

  test "CacheCardImageJob records failure status when caching fails" do
    stub_image_cache_service_failure("HTTP 404 Not Found") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
      assert_equal "failure", execution.status
      assert_equal false, execution.downloaded
      assert_equal false, execution.cache_hit
      assert_not_nil execution.error_message
      assert_match /404/, execution.error_message
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Structured JSON logging
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob logs cache_started event in JSON format" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"cache_started"/, log_content
      assert_match /"component":"CacheCardImageJob"/, log_content
      assert_match /"collection_item_id":#{@item.id}/, log_content
      assert_match /"card_id":"test-card-123"/, log_content
      assert_match /"timestamp":"#{Time.current.year}/, log_content
    end
  end

  test "CacheCardImageJob logs cache_completed event with result" do
    stub_image_cache_service_success(downloaded: true) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"cache_completed"/, log_content
      assert_match /"status":"success"/, log_content
      assert_match /"downloaded":true/, log_content
    end
  end

  test "CacheCardImageJob logs image_downloaded event when downloading" do
    stub_image_cache_service_success(downloaded: true, file_size: 45678) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"image_downloaded"/, log_content
      assert_match /"file_size_bytes":45678/, log_content
    end
  end

  test "CacheCardImageJob logs already_cached event when cache hit" do
    stub_image_cache_service_success(downloaded: false, cached: true) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"already_cached"/, log_content
      assert_match /"cache_hit":true/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Error logging
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob logs error with full context when download fails" do
    stub_image_cache_service_failure("Connection timeout after 30s") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Failures from the service are logged as cache_failed, not error_occurred
      assert_match /"event":"cache_failed"/, log_content
      assert_match /"error_message":"Connection timeout after 30s"/, log_content
      assert_match /"card_id":"test-card-123"/, log_content
    end
  end

  test "CacheCardImageJob logs cache_failed event" do
    stub_image_cache_service_failure("HTTP 500 Internal Server Error") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"cache_failed"/, log_content
      assert_match /"error_message":"HTTP 500 Internal Server Error"/, log_content
    end
  end

  test "CacheCardImageJob does not raise exception on failure" do
    stub_image_cache_service_failure("Network error") do
      # Should not raise - failures are logged but don't block execution
      assert_nothing_raised do
        CacheCardImageJob.perform_now(@item.id, @image_url)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Sensitive data redaction
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob does not log full file system paths in logs" do
    stub_image_cache_service_failure("Failed to write to /var/app/storage/images/secret/path/file.jpg") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Should redact full paths or convert to relative paths
      # This test assumes redaction is applied
      assert_no_match %r{/var/app/storage/images/secret/path}, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: ISO 8601 timestamp format
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob logs timestamps in ISO 8601 format" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # ISO 8601 format: 2026-02-08T10:30:45Z or 2026-02-08T10:30:45+00:00
      assert_match /"timestamp":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Log levels
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob uses appropriate log levels for different events" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Should have INFO level for normal operations
      assert_match /"level":"INFO"/, log_content
    end
  end

  test "CacheCardImageJob uses WARN level for failures" do
    stub_image_cache_service_failure("Download failed") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Failures should be WARN (not ERROR) since they don't block operations
      assert_match /"level":"WARN"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Non-blocking behavior
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob failure does not prevent inventory operations" do
    stub_image_cache_service_failure("Network error") do
      # Job should complete without raising, allowing inventory operations to continue
      assert_nothing_raised do
        CacheCardImageJob.perform_now(@item.id, @image_url)
      end

      # Execution record should still be created
      assert_equal 1, ImageCacheExecution.count
      assert_equal "failure", ImageCacheExecution.last.status
    end
  end

  private

  # ---------------------------------------------------------------------------
  # Test helper methods
  # ---------------------------------------------------------------------------

  def stub_image_cache_service_success(downloaded: true, cached: false, file_size: nil)
    service_instance = Object.new
    result = {
      success: true,
      downloaded: downloaded,
      cached: cached,
      file_size_bytes: file_size || (downloaded ? 45678 : nil),
      error: nil
    }
    service_instance.define_singleton_method(:call) { result }

    CardImageCacheService.stub :new, service_instance do
      yield
    end
  end

  def stub_image_cache_service_failure(error_message)
    service_instance = Object.new
    result = {
      success: false,
      downloaded: false,
      cached: false,
      file_size_bytes: nil,
      error: error_message
    }
    service_instance.define_singleton_method(:call) { result }

    CardImageCacheService.stub :new, service_instance do
      yield
    end
  end
end
