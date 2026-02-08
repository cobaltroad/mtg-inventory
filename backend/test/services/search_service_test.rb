require "test_helper"

class SearchServiceTest < ActiveSupport::TestCase
  # Disable parallelization for this test class to ensure cache works correctly
  parallelize(workers: 1)

  setup do
    # Use a real cache store for testing caching behavior (test env uses :null_store by default)
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear

    # Create test commanders and decklists
    @commander1 = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 5,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice"
    )

    @commander2 = Commander.create!(
      name: "Thrasios, Triton Hero",
      rank: 10,
      edhrec_url: "https://edhrec.com/commanders/thrasios-triton-hero"
    )

    @commander3 = Commander.create!(
      name: "Tymna the Weaver",
      rank: 15,
      edhrec_url: "https://edhrec.com/commanders/tymna-the-weaver"
    )

    # Decklist with Sol Ring
    @decklist1 = Decklist.create!(
      commander: @commander1,
      contents: [
        { "card_name" => "Sol Ring", "quantity" => 1 },
        { "card_name" => "Command Tower", "quantity" => 1 },
        { "card_name" => "Mana Crypt", "quantity" => 1 }
      ]
    )

    # Decklist with Sol Ring and Mana Vault
    @decklist2 = Decklist.create!(
      commander: @commander2,
      contents: [
        { "card_name" => "Sol Ring", "quantity" => 1 },
        { "card_name" => "Mana Vault", "quantity" => 1 }
      ]
    )

    # Decklist without Sol Ring
    @decklist3 = Decklist.create!(
      commander: @commander3,
      contents: [
        { "card_name" => "Command Tower", "quantity" => 1 },
        { "card_name" => "Arcane Signet", "quantity" => 1 }
      ]
    )
  end

  teardown do
    # Restore the original cache store
    Rails.cache = @original_cache
  end

  # ---------------------------------------------------------------------------
  # Search functionality tests
  # ---------------------------------------------------------------------------
  test "returns matching commanders with card details" do
    service = SearchService.new(query: "sol ring")
    results = service.call

    # Filter to only the commanders we created in setup
    our_commanders = [@commander1.id, @commander2.id, @commander3.id]
    our_results = results[:decklists].select { |r| our_commanders.include?(r[:commander_id]) }

    assert_equal 2, our_results.size, "Expected 2 commanders with Sol Ring in their decklists"

    # Verify first result structure
    first_result = our_results.first
    assert our_commanders.include?(first_result[:commander_id])
    assert_not_nil first_result[:commander_name]
    assert_not_nil first_result[:commander_rank]
    assert_equal 1, first_result[:match_count]
    assert_equal 1, first_result[:card_matches].size
    assert_equal "Sol Ring", first_result[:card_matches].first[:card_name]
    assert_equal 1, first_result[:card_matches].first[:quantity]
  end

  test "search is case insensitive" do
    service_lower = SearchService.new(query: "sol ring")
    service_upper = SearchService.new(query: "SOL RING")
    service_mixed = SearchService.new(query: "Sol Ring")

    results_lower = service_lower.call
    results_upper = service_upper.call
    results_mixed = service_mixed.call

    assert_equal results_lower[:decklists].size, results_upper[:decklists].size
    assert_equal results_lower[:decklists].size, results_mixed[:decklists].size
  end

  test "returns empty results when no matches found" do
    service = SearchService.new(query: "nonexistent card xyz")
    results = service.call

    assert_equal 0, results[:decklists].size
  end

  test "results are limited to 20" do
    # Create 25 commanders with decklists containing "test card"
    25.times do |i|
      commander = Commander.create!(
        name: "Test Commander #{i}",
        rank: i + 100,
        edhrec_url: "https://edhrec.com/commanders/test-#{i}"
      )
      Decklist.create!(
        commander: commander,
        contents: [
          { "card_name" => "Test Card", "quantity" => 1 }
        ]
      )
    end

    service = SearchService.new(query: "test card")
    results = service.call

    assert_equal 20, results[:decklists].size
  end

  test "results are ranked by relevance" do
    # Create a commander with multiple matches
    multi_match_commander = Commander.create!(
      name: "Multi Match Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/multi-match"
    )
    Decklist.create!(
      commander: multi_match_commander,
      contents: [
        { "card_name" => "Mana Crypt", "quantity" => 1 },
        { "card_name" => "Mana Vault", "quantity" => 1 },
        { "card_name" => "Mana Confluence", "quantity" => 1 }
      ]
    )

    service = SearchService.new(query: "mana")
    results = service.call

    # First result should be the commander with multiple "mana" cards
    assert results[:decklists].first[:commander_id] == multi_match_commander.id,
           "Expected multi-match commander to rank first"
    assert results[:decklists].first[:match_count] > 1,
           "Expected multiple matches for top result"
  end

  test "multiple search terms use OR logic" do
    service = SearchService.new(query: "sol vault")
    results = service.call

    # Should match both "sol ring" and "mana vault" decklists
    assert results[:decklists].size >= 2,
           "Expected matches for both 'sol' and 'vault' terms"
  end

  # ---------------------------------------------------------------------------
  # Caching tests
  # ---------------------------------------------------------------------------
  test "results are cached for 1 hour" do
    query = "sol ring"
    service1 = SearchService.new(query: query)
    results1 = service1.call

    # Verify cache key exists
    cache_key = "search:decklists:#{query.downcase.strip}"
    cached_results = Rails.cache.read(cache_key)
    assert_not_nil cached_results, "Expected results to be cached"

    # Second call should use cache (we can't easily verify this without mocking,
    # but we can verify the cache key pattern is correct)
    service2 = SearchService.new(query: query)
    results2 = service2.call

    assert_equal results1, results2
  end

  test "different queries generate different cache entries" do
    service1 = SearchService.new(query: "sol ring")
    service2 = SearchService.new(query: "mana vault")

    results1 = service1.call
    results2 = service2.call

    refute_equal results1, results2
  end

  test "cache normalizes query" do
    # Queries with different casing and whitespace should use same cache
    service1 = SearchService.new(query: "  SOL RING  ")
    results1 = service1.call

    service2 = SearchService.new(query: "sol ring")
    results2 = service2.call

    # Both should have same cache key
    cache_key1 = "search:decklists:sol ring"
    cached_1 = Rails.cache.read(cache_key1)
    assert_not_nil cached_1, "Expected normalized cache key to exist"
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------
  test "handles special characters in query" do
    # Create a card with special characters
    special_commander = Commander.create!(
      name: "Special Commander",
      rank: 50,
      edhrec_url: "https://edhrec.com/commanders/special"
    )
    Decklist.create!(
      commander: special_commander,
      contents: [
        { "card_name" => "Akroma's Memorial", "quantity" => 1 }
      ]
    )

    service = SearchService.new(query: "akroma's")
    results = service.call

    assert results[:decklists].size >= 1,
           "Expected to find cards with apostrophes"
  end

  test "returns card matches in decklist" do
    service = SearchService.new(query: "sol ring")
    results = service.call

    first_result = results[:decklists].first
    assert first_result[:card_matches].is_a?(Array),
           "Expected card_matches to be an array"
    assert first_result[:card_matches].first.key?(:card_name),
           "Expected card_matches to include card_name"
    assert first_result[:card_matches].first.key?(:quantity),
           "Expected card_matches to include quantity"
  end

  test "match_count reflects number of matching cards" do
    service = SearchService.new(query: "sol ring")
    results = service.call

    results[:decklists].each do |result|
      assert_equal result[:card_matches].size, result[:match_count],
                   "Expected match_count to equal number of card_matches"
    end
  end

  # ---------------------------------------------------------------------------
  # Inventory search tests
  # ---------------------------------------------------------------------------
  test "search_inventory returns empty array for empty inventory" do
    user = User.create!(email: "test5@example.com", name: "Test User 5")

    service = SearchService.new(query: "sol ring")
    results = service.search_inventory(user, "sol ring")

    assert_equal [], results
  end
end
