require "test_helper"
require "webmock/minitest"
require_relative "../support/execution_logging_test_concern"

class ImageCacheExecutionLoggingTest < ActiveJob::TestCase
  include ExecutionLoggingTestConcern

  setup do
    # Disable VCR for these tests since we're using WebMock stubs directly
    VCR.turn_off!(ignore_cassettes: true)
    WebMock.enable!

    # Clear any existing data in proper order (dependencies first)
    ImageCacheExecution.delete_all
    CollectionItem.delete_all
    User.delete_all

    # Stub card details API call that happens during collection item creation
    stub_request(:get, "https://api.scryfall.com/cards/test-card-123")
      .to_return(status: 200, body: { id: "test-card-123", name: "Test Card" }.to_json)

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
  end

  teardown do
    # Re-enable VCR
    VCR.turn_on!
  end

  # ---------------------------------------------------------------------------
  # ExecutionLoggingTestConcern interface implementation
  # ---------------------------------------------------------------------------

  def perform_job
    CacheCardImageJob.perform_now(@item.id, @image_url)
  end

  def execution_model
    ImageCacheExecution
  end

  def job_class
    CacheCardImageJob
  end

  def job_component_name
    "CacheCardImageJob"
  end

  def stub_success
    stub_image_cache_service_success do
      yield
    end
  end

  def stub_error(error)
    stub_image_cache_service_failure(error.message) do
      yield
    end
  end

  def job_raises_on_error?
    # CacheCardImageJob handles errors gracefully without raising exceptions
    false
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Job-specific execution record tracking
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob records collection_item_id and card_id" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
      assert_equal @item.id, execution.collection_item_id
      assert_equal @item.card_id, execution.card_id
    end
  end

  test "CacheCardImageJob records downloaded status and file size" do
    stub_image_cache_service_success(downloaded: true, file_size: 45678) do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      execution = ImageCacheExecution.last
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

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Job-specific logging
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob logs cache_started event with collection_item_id and card_id" do
    stub_image_cache_service_success do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"cache_started"/, log_content
      assert_match /"collection_item_id":#{@item.id}/, log_content
      assert_match /"card_id":"test-card-123"/, log_content
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

  test "CacheCardImageJob logs cache_failed event on failure" do
    stub_image_cache_service_failure("HTTP 500 Internal Server Error") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      assert_match /"event":"cache_failed"/, log_content
      assert_match /"error_message":"HTTP 500 Internal Server Error"/, log_content
    end
  end

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Non-blocking behavior
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob does not raise exception on failure" do
    stub_image_cache_service_failure("Network error") do
      # Should not raise - failures are logged but don't block execution
      assert_nothing_raised do
        CacheCardImageJob.perform_now(@item.id, @image_url)
      end
    end
  end

  test "CacheCardImageJob records failure status without raising" do
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

  test "CacheCardImageJob uses WARN level for failures" do
    stub_image_cache_service_failure("Download failed") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Failures should be WARN (not ERROR) since they don't block operations
      assert_match /"level":"WARN"/, log_content
    end
  end

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

  # ---------------------------------------------------------------------------
  # CacheCardImageJob: Sensitive data redaction for file paths
  # ---------------------------------------------------------------------------
  test "CacheCardImageJob does not log full file system paths" do
    stub_image_cache_service_failure("Failed to write to /var/app/storage/images/secret/path/file.jpg") do
      CacheCardImageJob.perform_now(@item.id, @image_url)

      log_content = @log_output.string
      # Should redact full paths or convert to relative paths
      assert_no_match %r{/var/app/storage/images/secret/path}, log_content
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
