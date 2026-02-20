require "test_helper"
require "webmock/minitest"

class InventoryColorFilteringTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Color Filtering Tests for Issue #207
  # Testing color-based filtering of inventory items with TDD methodology
  # ---------------------------------------------------------------------------

  setup do
    CollectionItem.delete_all
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
    WebMock.reset!

    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  def parse_inventory_response
    body = JSON.parse(response.body)
    body.is_a?(Hash) && body.key?("items") ? body["items"] : body
  end

  # Stub Scryfall API with card details including colors
  def stub_card_with_colors(card_id, name:, colors:)
    stub_request(:get, "https://api.scryfall.com/cards/#{card_id}")
      .to_return(
        status: 200,
        body: {
          id: card_id,
          name: name,
          set: "TST",
          set_name: "Test Set",
          collector_number: "1",
          colors: colors,
          released_at: "2024-01-01",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )
  end

  # ---------------------------------------------------------------------------
  # AC1: Single Color Filter Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory?colors=W returns only white cards" do
    # Create test cards with different colors
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "Plains Walker", colors: ["W"])
    stub_card_with_colors("blue_1", name: "Island Sage", colors: ["U"])

    get api_path("/inventory?colors=W")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size, "Should return only white cards"
    assert_equal "white_1", items.first["card_id"]
    assert_equal "Plains Walker", items.first["card_name"]
  end

  test "GET /api/inventory?colors=U returns only blue cards" do
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)
    red_card = CollectionItem.create!(user: @user, card_id: "red_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("blue_1", name: "Counterspell", colors: ["U"])
    stub_card_with_colors("red_1", name: "Lightning Bolt", colors: ["R"])

    get api_path("/inventory?colors=U")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size
    assert_equal "blue_1", items.first["card_id"]
  end

  test "GET /api/inventory?colors=B returns only black cards" do
    black_card = CollectionItem.create!(user: @user, card_id: "black_1", collection_type: "inventory", quantity: 1)
    green_card = CollectionItem.create!(user: @user, card_id: "green_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("black_1", name: "Dark Ritual", colors: ["B"])
    stub_card_with_colors("green_1", name: "Llanowar Elves", colors: ["G"])

    get api_path("/inventory?colors=B")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size
    assert_equal "black_1", items.first["card_id"]
  end

  test "GET /api/inventory?colors=R returns only red cards" do
    red_card = CollectionItem.create!(user: @user, card_id: "red_1", collection_type: "inventory", quantity: 1)
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("red_1", name: "Lightning Bolt", colors: ["R"])
    stub_card_with_colors("white_1", name: "Swords to Plowshares", colors: ["W"])

    get api_path("/inventory?colors=R")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size
    assert_equal "red_1", items.first["card_id"]
  end

  test "GET /api/inventory?colors=G returns only green cards" do
    green_card = CollectionItem.create!(user: @user, card_id: "green_1", collection_type: "inventory", quantity: 1)
    black_card = CollectionItem.create!(user: @user, card_id: "black_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("green_1", name: "Giant Growth", colors: ["G"])
    stub_card_with_colors("black_1", name: "Doom Blade", colors: ["B"])

    get api_path("/inventory?colors=G")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size
    assert_equal "green_1", items.first["card_id"]
  end

  test "GET /api/inventory?colors=W excludes multicolor cards with white" do
    mono_white = CollectionItem.create!(user: @user, card_id: "mono_w", collection_type: "inventory", quantity: 1)
    dual_wu = CollectionItem.create!(user: @user, card_id: "dual_wu", collection_type: "inventory", quantity: 1)
    dual_wb = CollectionItem.create!(user: @user, card_id: "dual_wb", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("mono_w", name: "Serra Angel", colors: ["W"])
    stub_card_with_colors("dual_wu", name: "Azorius Charm", colors: ["W", "U"])
    stub_card_with_colors("dual_wb", name: "Orzhov Charm", colors: ["W", "B"])

    get api_path("/inventory?colors=W")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size, "Should return ONLY mono-white (multicolor excluded)"
    assert_equal "mono_w", items.first["card_id"]
    card_ids = items.map { |item| item["card_id"] }
    assert_not_includes card_ids, "dual_wu", "W/U multicolor card excluded"
    assert_not_includes card_ids, "dual_wb", "W/B multicolor card excluded"
  end

  # ---------------------------------------------------------------------------
  # AC2: Multicolor Filter Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory?colors=multicolor returns only cards with 2+ colors" do
    # Create various card types
    mono_white = CollectionItem.create!(user: @user, card_id: "mono_w", collection_type: "inventory", quantity: 1)
    dual_color = CollectionItem.create!(user: @user, card_id: "dual_ub", collection_type: "inventory", quantity: 1)
    tri_color = CollectionItem.create!(user: @user, card_id: "tri_wub", collection_type: "inventory", quantity: 1)
    colorless = CollectionItem.create!(user: @user, card_id: "colorless_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("mono_w", name: "Wrath of God", colors: ["W"])
    stub_card_with_colors("dual_ub", name: "Dimir Signet", colors: ["U", "B"])
    stub_card_with_colors("tri_wub", name: "Esper Charm", colors: ["W", "U", "B"])
    stub_card_with_colors("colorless_1", name: "Sol Ring", colors: [])

    get api_path("/inventory?colors=multicolor")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should return only multicolor cards (2+ colors)"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "dual_ub"
    assert_includes card_ids, "tri_wub"
  end

  # ---------------------------------------------------------------------------
  # AC3: Colorless Filter Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory?colors=colorless returns only colorless cards" do
    colorless_artifact = CollectionItem.create!(user: @user, card_id: "artifact_1", collection_type: "inventory", quantity: 1)
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    colorless_eldrazi = CollectionItem.create!(user: @user, card_id: "eldrazi_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("artifact_1", name: "Mana Vault", colors: [])
    stub_card_with_colors("white_1", name: "Serra Angel", colors: ["W"])
    stub_card_with_colors("eldrazi_1", name: "Kozilek", colors: [])

    get api_path("/inventory?colors=colorless")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should return only colorless cards"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "artifact_1"
    assert_includes card_ids, "eldrazi_1"
  end

  test "GET /api/inventory?colors=colorless excludes double-faced cards with color identity" do
    # Double-faced cards have null colors but non-empty color_identity
    colorless_artifact = CollectionItem.create!(user: @user, card_id: "colorless_1", collection_type: "inventory", quantity: 1)
    dfc_blue = CollectionItem.create!(user: @user, card_id: "dfc_blue", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("colorless_1", name: "Sol Ring", colors: [])
    # Simulate double-faced card with null colors but U color_identity
    stub_request(:get, "https://api.scryfall.com/cards/dfc_blue")
      .to_return(
        status: 200,
        body: {
          id: "dfc_blue",
          name: "Test DFC // Blue Side",
          set: "TST",
          set_name: "Test Set",
          collector_number: "1",
          colors: nil,
          color_identity: ["U"],
          released_at: "2024-01-01",
          image_uris: {
            normal: "https://cards.scryfall.io/normal/front/test.jpg"
          }
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get api_path("/inventory?colors=colorless")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size, "Should return only truly colorless cards"
    assert_equal "colorless_1", items.first["card_id"]
    card_ids = items.map { |item| item["card_id"] }
    assert_not_includes card_ids, "dfc_blue", "DFC with color identity should be excluded"
  end

  # ---------------------------------------------------------------------------
  # AC4: Multiple Color Filters (OR Logic) Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory?colors=W,U returns mono-white OR mono-blue (no multicolor)" do
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)
    red_card = CollectionItem.create!(user: @user, card_id: "red_1", collection_type: "inventory", quantity: 1)
    azorius_card = CollectionItem.create!(user: @user, card_id: "wu_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "Path to Exile", colors: ["W"])
    stub_card_with_colors("blue_1", name: "Brainstorm", colors: ["U"])
    stub_card_with_colors("red_1", name: "Shock", colors: ["R"])
    stub_card_with_colors("wu_1", name: "Supreme Verdict", colors: ["W", "U"])

    get api_path("/inventory?colors=W,U")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should return mono-white OR mono-blue (no multicolor)"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "white_1"
    assert_includes card_ids, "blue_1"
    assert_not_includes card_ids, "wu_1", "Multicolor cards excluded without M filter"
    assert_not_includes card_ids, "red_1"
  end

  test "GET /api/inventory?colors=B,R,G returns mono-black OR mono-red OR mono-green (no multicolor)" do
    black_card = CollectionItem.create!(user: @user, card_id: "black_1", collection_type: "inventory", quantity: 1)
    red_card = CollectionItem.create!(user: @user, card_id: "red_1", collection_type: "inventory", quantity: 1)
    green_card = CollectionItem.create!(user: @user, card_id: "green_1", collection_type: "inventory", quantity: 1)
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    jund_card = CollectionItem.create!(user: @user, card_id: "brg_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("black_1", name: "Thoughtseize", colors: ["B"])
    stub_card_with_colors("red_1", name: "Bolt", colors: ["R"])
    stub_card_with_colors("green_1", name: "Rampant Growth", colors: ["G"])
    stub_card_with_colors("white_1", name: "Disenchant", colors: ["W"])
    stub_card_with_colors("brg_1", name: "Jund Charm", colors: ["B", "R", "G"])

    get api_path("/inventory?colors=B,R,G")

    assert_response :success
    items = parse_inventory_response
    assert_equal 3, items.size, "Should return mono-color B, R, or G (no multicolor)"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "black_1"
    assert_includes card_ids, "red_1"
    assert_includes card_ids, "green_1"
    assert_not_includes card_ids, "brg_1", "Multicolor cards excluded without M filter"
    assert_not_includes card_ids, "white_1"
  end

  # ---------------------------------------------------------------------------
  # AC5: Clear Filters / No Filter Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory without color parameter returns all cards" do
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)
    colorless_card = CollectionItem.create!(user: @user, card_id: "colorless_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "Plains", colors: ["W"])
    stub_card_with_colors("blue_1", name: "Island", colors: ["U"])
    stub_card_with_colors("colorless_1", name: "Wastes", colors: [])

    get api_path("/inventory")

    assert_response :success
    items = parse_inventory_response
    assert_equal 3, items.size, "Should return all cards when no filter applied"
  end

  test "GET /api/inventory with empty colors parameter returns all cards" do
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "Savannah Lions", colors: ["W"])
    stub_card_with_colors("blue_1", name: "Delver", colors: ["U"])

    get api_path("/inventory?colors=")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Empty colors parameter should return all cards"
  end

  # ---------------------------------------------------------------------------
  # Edge Cases and Validation Tests
  # ---------------------------------------------------------------------------

  test "GET /api/inventory?colors=INVALID returns all cards (graceful degradation)" do
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "Test Card", colors: ["W"])

    get api_path("/inventory?colors=INVALID")

    assert_response :success
    items = parse_inventory_response
    assert_equal 1, items.size, "Invalid color should be ignored and return all cards"
  end

  test "GET /api/inventory?colors=W,INVALID,U filters valid colors only" do
    white_card = CollectionItem.create!(user: @user, card_id: "white_1", collection_type: "inventory", quantity: 1)
    blue_card = CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)
    red_card = CollectionItem.create!(user: @user, card_id: "red_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_1", name: "W Card", colors: ["W"])
    stub_card_with_colors("blue_1", name: "U Card", colors: ["U"])
    stub_card_with_colors("red_1", name: "R Card", colors: ["R"])

    get api_path("/inventory?colors=W,INVALID,U")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should filter W and U, ignore invalid"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "white_1"
    assert_includes card_ids, "blue_1"
  end

  test "color filter works with pagination" do
    # Create multiple white cards
    5.times do |i|
      CollectionItem.create!(user: @user, card_id: "white_#{i}", collection_type: "inventory", quantity: 1)
      stub_card_with_colors("white_#{i}", name: "White Card #{i}", colors: ["W"])
    end

    # Create non-white cards
    CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)
    stub_card_with_colors("blue_1", name: "Blue Card", colors: ["U"])

    get api_path("/inventory?colors=W&per_page=3&page=1")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 3, body["items"].size, "Should return 3 items per page"
    assert_equal 5, body["total_count"], "Total count should be 5 white cards"
    assert_equal 2, body["total_pages"], "Should have 2 pages (5 cards / 3 per page)"
  end

  test "color filter works with sorting" do
    # Create cards with different colors and names
    CollectionItem.create!(user: @user, card_id: "white_z", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "white_a", collection_type: "inventory", quantity: 1)
    CollectionItem.create!(user: @user, card_id: "blue_1", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("white_z", name: "Zealot", colors: ["W"])
    stub_card_with_colors("white_a", name: "Angel", colors: ["W"])
    stub_card_with_colors("blue_1", name: "Brainstorm", colors: ["U"])

    get api_path("/inventory?colors=W&sort=name-asc")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size
    assert_equal "Angel", items.first["card_name"], "Should sort filtered cards"
    assert_equal "Zealot", items.last["card_name"]
  end

  test "combining multicolor filter with single color filter" do
    mono_white = CollectionItem.create!(user: @user, card_id: "mono_w", collection_type: "inventory", quantity: 1)
    dual_wb = CollectionItem.create!(user: @user, card_id: "dual_wb", collection_type: "inventory", quantity: 1)
    dual_ub = CollectionItem.create!(user: @user, card_id: "dual_ub", collection_type: "inventory", quantity: 1)

    stub_card_with_colors("mono_w", name: "Plains Walker", colors: ["W"])
    stub_card_with_colors("dual_wb", name: "Orzhov Charm", colors: ["W", "B"])
    stub_card_with_colors("dual_ub", name: "Dimir Charm", colors: ["U", "B"])

    get api_path("/inventory?colors=multicolor,W")

    assert_response :success
    items = parse_inventory_response
    assert_equal 2, items.size, "Should return mono-white + multicolor cards containing white"
    card_ids = items.map { |item| item["card_id"] }
    assert_includes card_ids, "mono_w", "Mono-white card included"
    assert_includes card_ids, "dual_wb", "Multicolor card with W included"
    assert_not_includes card_ids, "dual_ub", "Multicolor card without W excluded"
  end
end
