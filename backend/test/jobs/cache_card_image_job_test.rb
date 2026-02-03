require "test_helper"
require "webmock/minitest"

class CacheCardImageJobTest < ActiveJob::TestCase
  setup do
    WebMock.reset!

    # Ensure the default user exists
    CollectionItem.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)

    # Create a test collection item
    @collection_item = CollectionItem.create!(
      user: @user,
      card_id: "test-card-uuid",
      collection_type: "inventory",
      quantity: 1
    )

    @image_url = "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg"
  end

  teardown do
    # Clean up any attached images
    @collection_item.reload
    @collection_item.cached_image.purge if @collection_item.cached_image.attached?
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test background job for caching card images
  # ---------------------------------------------------------------------------
  test "job can be enqueued" do
    assert_enqueued_with(job: CacheCardImageJob, args: [@collection_item.id, @image_url]) do
      CacheCardImageJob.perform_later(@collection_item.id, @image_url)
    end
  end

  test "job calls CardImageCacheService with correct parameters" do
    stub_image_download(@image_url)

    # Perform job
    CacheCardImageJob.perform_now(@collection_item.id, @image_url)

    # Verify image was cached
    @collection_item.reload
    assert @collection_item.cached_image.attached?, "Image should be cached after job runs"
    assert_equal "#{@collection_item.card_id}.jpg", @collection_item.cached_image.filename.to_s
  end

  test "job handles missing collection item gracefully" do
    invalid_id = 999999

    # Should not raise exception
    assert_nothing_raised do
      CacheCardImageJob.perform_now(invalid_id, @image_url)
    end
  end

  test "job handles service failures gracefully" do
    stub_request(:get, @image_url)
      .to_raise(SocketError.new("Connection failed"))

    # Should not raise exception
    assert_nothing_raised do
      CacheCardImageJob.perform_now(@collection_item.id, @image_url)
    end

    # Collection item should still exist
    assert CollectionItem.exists?(@collection_item.id)

    # Image should not be attached
    @collection_item.reload
    refute @collection_item.cached_image.attached?
  end

  test "job is idempotent - can be run multiple times safely" do
    stub_image_download(@image_url)

    # Run job twice
    CacheCardImageJob.perform_now(@collection_item.id, @image_url)
    @collection_item.reload
    assert @collection_item.cached_image.attached?

    # Second run should not cause errors
    assert_nothing_raised do
      CacheCardImageJob.perform_now(@collection_item.id, @image_url)
    end

    @collection_item.reload
    assert @collection_item.cached_image.attached?
  end

  test "job logs when successfully caching image" do
    stub_image_download(@image_url)

    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    CacheCardImageJob.perform_now(@collection_item.id, @image_url)

    Rails.logger = old_logger

    assert log_output.string.include?("Successfully cached"), "Should log success"
    assert log_output.string.include?("test-card-uuid"), "Should include card ID"
  end

  test "job logs when image is already cached" do
    stub_image_download(@image_url)

    # Cache image first
    CacheCardImageJob.perform_now(@collection_item.id, @image_url)

    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    # Run again
    CacheCardImageJob.perform_now(@collection_item.id, @image_url)

    Rails.logger = old_logger

    assert log_output.string.include?("already cached"), "Should log that image is already cached"
  end

  test "job handles nil image URL gracefully" do
    assert_nothing_raised do
      CacheCardImageJob.perform_now(@collection_item.id, nil)
    end

    @collection_item.reload
    refute @collection_item.cached_image.attached?
  end

  test "job handles blank image URL gracefully" do
    assert_nothing_raised do
      CacheCardImageJob.perform_now(@collection_item.id, "")
    end

    @collection_item.reload
    refute @collection_item.cached_image.attached?
  end

  private

  def stub_image_download(url)
    # Return a minimal valid JPEG binary data
    jpeg_data = "\xFF\xD8\xFF\xE0\x00\x10JFIF".b
    stub_request(:get, url)
      .to_return(
        status: 200,
        body: jpeg_data,
        headers: { "Content-Type" => "image/jpeg" }
      )
  end
end
