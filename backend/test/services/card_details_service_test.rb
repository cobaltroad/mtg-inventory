require "test_helper"
require "webmock/minitest"

class CardDetailsServiceTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    # Use memory store for cache testing instead of null store
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    # Restore original cache
    Rails.cache = @original_cache
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test fetching card details from Scryfall API
  # ---------------------------------------------------------------------------
  test "fetches card details from Scryfall API using card UUID" do
    card_id = "test-uuid-123"
    stub_scryfall_card_request(card_id)

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Black Lotus", result[:name]
    assert_equal "LEA", result[:set]
    assert_equal "Limited Edition Alpha", result[:set_name]
    assert_equal "234", result[:collector_number]
    assert_equal "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg", result[:image_url]
  end

  test "caches card details to avoid repeated API calls" do
    card_id = "cached-uuid-456"
    stub = stub_scryfall_card_request(card_id)

    # First call should hit the API
    service = CardDetailsService.new(card_id: card_id)
    result1 = service.call
    assert_equal "Black Lotus", result1[:name]

    # Verify the result is now in cache (v3 cache key includes promo_types)
    cached_result = Rails.cache.read("card_details:v3:#{card_id}")
    assert_not_nil cached_result
    assert_equal "Black Lotus", cached_result[:name]

    # Second call should use cache, not hitting API again
    service2 = CardDetailsService.new(card_id: card_id)
    result2 = service2.call
    assert_equal "Black Lotus", result2[:name]

    # Verify API was only called once
    assert_requested stub, times: 1
  end

  test "cache respects TTL and expires after configured time" do
    card_id = "ttl-uuid-789"
    stub = stub_scryfall_card_request(card_id)

    service = CardDetailsService.new(card_id: card_id)

    # First call
    service.call

    # Simulate cache expiration by clearing cache
    Rails.cache.clear

    # Second call should hit API again after cache cleared
    service2 = CardDetailsService.new(card_id: card_id)
    service2.call

    # Verify API was called twice
    assert_requested stub, times: 2
  end

  test "returns nil for non-existent card" do
    card_id = "nonexistent-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(status: 404, body: '{"object":"error","code":"not_found"}')

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_nil result
  end

  test "raises NetworkError on connection failure" do
    card_id = "network-error-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_raise(SocketError.new("Connection failed"))

    service = CardDetailsService.new(card_id: card_id)

    assert_raises(CardDetailsService::NetworkError) do
      service.call
    end
  end

  test "raises TimeoutError on request timeout" do
    card_id = "timeout-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_timeout

    service = CardDetailsService.new(card_id: card_id)

    assert_raises(CardDetailsService::TimeoutError) do
      service.call
    end
  end

  test "handles cards with double-faced images" do
    card_id = "double-faced-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Delver of Secrets // Insectile Aberration",
          set: "ISD",
          set_name: "Innistrad",
          collector_number: "51",
          card_faces: [
            {
              image_uris: {
                normal: "https://cards.scryfall.io/normal/front/d/e/delver-front.jpg"
              }
            },
            {
              image_uris: {
                normal: "https://cards.scryfall.io/normal/back/d/e/delver-back.jpg"
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal "Delver of Secrets // Insectile Aberration", result[:name]
    assert_equal "https://cards.scryfall.io/normal/front/d/e/delver-front.jpg", result[:image_url]
  end

  # ---------------------------------------------------------------------------
  # RED Phase: Test fetching promo_types from Scryfall API
  # ---------------------------------------------------------------------------
  test "fetches promo_types for halofoil cards" do
    card_id = "halofoil-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Utvara Hellkite",
          set: "SLD",
          set_name: "Secret Lair Drop",
          collector_number: "1273",
          finishes: [ "foil" ],
          promo_types: [ "halofoil" ],
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/u/h/utvara.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Utvara Hellkite", result[:name]
    assert_equal [ "halofoil" ], result[:promo_types]
  end

  test "fetches promo_types for rainbowfoil cards" do
    card_id = "rainbowfoil-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Price of Glory",
          set: "SLD",
          set_name: "Secret Lair Drop",
          collector_number: "1525",
          finishes: [ "foil" ],
          promo_types: [ "rainbowfoil" ],
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/p/o/price.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Price of Glory", result[:name]
    assert_equal [ "rainbowfoil" ], result[:promo_types]
  end

  test "fetches promo_types for surgefoil cards" do
    card_id = "surgefoil-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Bastion of Remembrance",
          set: "PIP",
          set_name: "Fallout",
          collector_number: "710",
          finishes: [ "foil" ],
          promo_types: [ "surgefoil" ],
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/b/a/bastion.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Bastion of Remembrance", result[:name]
    assert_equal [ "surgefoil" ], result[:promo_types]
  end

  test "returns empty array for promo_types when not present" do
    card_id = "no-promo-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Lightning Bolt",
          set: "LEA",
          set_name: "Limited Edition Alpha",
          collector_number: "161",
          finishes: [ "nonfoil" ],
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/l/b/bolt.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Lightning Bolt", result[:name]
    assert_equal [], result[:promo_types]
  end

  test "handles cards with multiple promo types" do
    card_id = "multi-promo-uuid"
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Test Card",
          set: "TST",
          set_name: "Test Set",
          collector_number: "1",
          finishes: [ "foil" ],
          promo_types: [ "halofoil", "prerelease" ],
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/t/t/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    service = CardDetailsService.new(card_id: card_id)
    result = service.call

    assert_equal card_id, result[:id]
    assert_equal "Test Card", result[:name]
    assert_equal [ "halofoil", "prerelease" ], result[:promo_types]
  end

  private

  def stub_scryfall_card_request(card_id)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: "Black Lotus",
          set: "LEA",
          set_name: "Limited Edition Alpha",
          collector_number: "234",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/b/l/black-lotus.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end
end
