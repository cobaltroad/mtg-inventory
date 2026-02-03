require "test_helper"
require "webmock/minitest"

class CardImageCacheServiceTest < ActiveSupport::TestCase
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
    @collection_item.cached_image.purge if @collection_item.cached_image.attached?
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test downloading and caching card images
  # ---------------------------------------------------------------------------
  test "downloads image from Scryfall and attaches to collection item" do
    stub_image_download(@image_url)

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    assert result[:success], "Service should return success"
    assert @collection_item.cached_image.attached?, "Image should be attached to collection item"
    assert_equal "#{@collection_item.card_id}.jpg", @collection_item.cached_image.filename.to_s
  end

  test "generates correct filename from card ID" do
    stub_image_download(@image_url)

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    service.call

    assert_equal "test-card-uuid.jpg", @collection_item.cached_image.filename.to_s
  end

  test "skips download if image already cached" do
    # First call - should download
    stub1 = stub_image_download(@image_url)
    service1 = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result1 = service1.call
    assert result1[:success]
    assert result1[:downloaded], "First call should download image"
    assert_requested stub1, times: 1

    # Reload to see the attachment
    @collection_item.reload
    assert @collection_item.cached_image.attached?, "Image should be attached after first call"

    # Second call - should skip because image is already cached
    WebMock.reset! # Clear previous stubs
    stub2 = stub_image_download(@image_url)
    service2 = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result2 = service2.call
    assert result2[:success]
    refute result2[:downloaded], "Second call should skip download"
    assert result2[:cached], "Second call should indicate already cached"

    # Verify API was not called for second request
    assert_requested stub2, times: 0
  end

  test "handles network failures gracefully without raising exception" do
    stub_request(:get, @image_url)
      .to_raise(SocketError.new("Connection failed"))

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)

    # Should not raise exception
    assert_nothing_raised do
      result = service.call
      refute result[:success], "Service should return failure"
      assert_includes result[:error], "Network error"
    end

    refute @collection_item.cached_image.attached?, "Image should not be attached on network failure"
  end

  test "handles HTTP timeout gracefully" do
    stub_request(:get, @image_url)
      .to_timeout

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    refute result[:success], "Service should return failure"
    assert_includes result[:error], "Timeout"
    refute @collection_item.cached_image.attached?
  end

  test "handles HTTP error responses gracefully" do
    stub_request(:get, @image_url)
      .to_return(status: 500, body: "Internal Server Error")

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    refute result[:success], "Service should return failure"
    assert_includes result[:error], "HTTP error"
    refute @collection_item.cached_image.attached?
  end

  test "handles invalid image data gracefully" do
    stub_request(:get, @image_url)
      .to_return(status: 200, body: "not an image", headers: { "Content-Type" => "text/html" })

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    # Service should still succeed in attaching, but we log a warning
    # Active Storage will attach any data, so this tests graceful handling
    assert result[:success], "Service should handle invalid image data"
  end

  test "handles missing image URL gracefully" do
    service = CardImageCacheService.new(collection_item: @collection_item, image_url: nil)
    result = service.call

    refute result[:success], "Service should return failure for nil URL"
    assert_includes result[:error], "URL"
    refute @collection_item.cached_image.attached?
  end

  test "handles blank image URL gracefully" do
    service = CardImageCacheService.new(collection_item: @collection_item, image_url: "")
    result = service.call

    refute result[:success], "Service should return failure for blank URL"
    assert_includes result[:error], "URL"
    refute @collection_item.cached_image.attached?
  end

  test "returns success status hash with downloaded flag" do
    stub_image_download(@image_url)

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    assert result.is_a?(Hash), "Result should be a hash"
    assert result.key?(:success), "Result should have :success key"
    assert result.key?(:downloaded), "Result should have :downloaded key"
    assert result[:success]
    assert result[:downloaded]
  end

  test "returns failure status hash with error message on failure" do
    stub_request(:get, @image_url)
      .to_raise(SocketError.new("Connection failed"))

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)
    result = service.call

    assert result.is_a?(Hash), "Result should be a hash"
    assert result.key?(:success), "Result should have :success key"
    assert result.key?(:error), "Result should have :error key"
    refute result[:success]
    assert_not_nil result[:error]
  end

  test "logs errors to Rails logger" do
    stub_request(:get, @image_url)
      .to_raise(SocketError.new("Connection failed"))

    service = CardImageCacheService.new(collection_item: @collection_item, image_url: @image_url)

    # Capture log output
    log_output = StringIO.new
    old_logger = Rails.logger
    Rails.logger = Logger.new(log_output)

    service.call

    Rails.logger = old_logger

    assert log_output.string.include?("Failed to cache image"), "Should log error message"
    assert log_output.string.include?("test-card-uuid"), "Should include card ID in log"
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
