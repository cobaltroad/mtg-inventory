require "test_helper"

class CommandersControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Clear existing data to ensure test isolation
    Decklist.delete_all
    Commander.delete_all
  end

  def api_path(path)
    "#{ENV.fetch('PUBLIC_API_PATH', '/api')}#{path}"
  end

  # ---------------------------------------------------------------------------
  # #index -- returns all commanders ordered by rank
  # ---------------------------------------------------------------------------
  test "GET /api/commanders returns 200 and empty array when no commanders exist" do
    get api_path("/commanders")

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body
  end

  test "GET /api/commanders returns all commanders ordered by rank ascending" do
    # Create commanders with decklists in non-rank order to verify sorting
    commander3 = Commander.create!(
      name: "Thrasios, Triton Hero",
      rank: 3,
      edhrec_url: "https://edhrec.com/commanders/thrasios-triton-hero",
      last_scraped_at: Time.zone.parse("2026-02-05T10:00:00Z")
    )
    decklist3 = Decklist.create!(
      commander: commander3,
      contents: [
        { "card_id" => "abc-123", "card_name" => "Sol Ring", "quantity" => 1 }
      ]
    )

    commander1 = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )
    decklist1 = Decklist.create!(
      commander: commander1,
      contents: [
        { "card_id" => "def-456", "card_name" => "Command Tower", "quantity" => 1 },
        { "card_id" => "ghi-789", "card_name" => "Sol Ring", "quantity" => 1 }
      ]
    )

    commander2 = Commander.create!(
      name: "Muldrotha, the Gravetide",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/muldrotha-the-gravetide",
      last_scraped_at: Time.zone.parse("2026-02-03T15:30:00Z")
    )
    decklist2 = Decklist.create!(
      commander: commander2,
      contents: [
        { "card_id" => "jkl-012", "card_name" => "Eternal Witness", "quantity" => 1 },
        { "card_id" => "mno-345", "card_name" => "Sakura-Tribe Elder", "quantity" => 1 },
        { "card_id" => "pqr-678", "card_name" => "Sol Ring", "quantity" => 1 }
      ]
    )

    get api_path("/commanders")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 3, body.length

    # Verify ordering by rank
    assert_equal commander1.id, body[0]["id"]
    assert_equal commander2.id, body[1]["id"]
    assert_equal commander3.id, body[2]["id"]

    # Verify first commander has all required fields
    assert_equal "Atraxa, Praetors' Voice", body[0]["name"]
    assert_equal 1, body[0]["rank"]
    assert_equal "https://edhrec.com/commanders/atraxa-praetors-voice", body[0]["edhrec_url"]
    assert_equal "2026-02-02T02:00:00.000Z", body[0]["last_scraped_at"]
    assert_equal 2, body[0]["card_count"]

    # Verify second commander
    assert_equal "Muldrotha, the Gravetide", body[1]["name"]
    assert_equal 2, body[1]["rank"]
    assert_equal 3, body[1]["card_count"]

    # Verify third commander
    assert_equal "Thrasios, Triton Hero", body[2]["name"]
    assert_equal 3, body[2]["rank"]
    assert_equal 1, body[2]["card_count"]
  end

  test "GET /api/commanders includes card_count of 0 when commander has no decklist" do
    commander = Commander.create!(
      name: "Commander Without Decklist",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )

    get api_path("/commanders")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body.length
    assert_equal 0, body[0]["card_count"]
  end

  # ---------------------------------------------------------------------------
  # #show -- returns single commander with decklist contents
  # ---------------------------------------------------------------------------
  test "GET /api/commanders/:id returns single commander with decklist contents" do
    commander = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )

    decklist = Decklist.create!(
      commander: commander,
      contents: [
        {
          "card_id" => "abc456-xyz8910",
          "card_name" => "Atraxa, Praetors' Voice",
          "quantity" => 1,
          "is_commander" => true
        },
        {
          "card_id" => "abc123-def456",
          "card_name" => "Sol Ring",
          "quantity" => 1
        },
        {
          "card_id" => "xyz789-uvw012",
          "card_name" => "Command Tower",
          "quantity" => 1
        }
      ]
    )

    get api_path("/commanders/#{commander.id}")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal commander.id, body["id"]
    assert_equal "Atraxa, Praetors' Voice", body["name"]
    assert_equal 1, body["rank"]
    assert_equal "https://edhrec.com/commanders/atraxa-praetors-voice", body["edhrec_url"]
    assert_equal "2026-02-02T02:00:00.000Z", body["last_scraped_at"]
    assert_equal 3, body["card_count"]

    # Verify cards array
    assert_equal 3, body["cards"].length

    # Verify first card (commander)
    assert_equal "abc456-xyz8910", body["cards"][0]["card_id"]
    assert_equal "Atraxa, Praetors' Voice", body["cards"][0]["card_name"]
    assert_equal 1, body["cards"][0]["quantity"]
    assert_equal true, body["cards"][0]["is_commander"]

    # Verify second card
    assert_equal "abc123-def456", body["cards"][1]["card_id"]
    assert_equal "Sol Ring", body["cards"][1]["card_name"]
    assert_equal 1, body["cards"][1]["quantity"]
    assert_nil body["cards"][1]["is_commander"]

    # Verify third card
    assert_equal "xyz789-uvw012", body["cards"][2]["card_id"]
    assert_equal "Command Tower", body["cards"][2]["card_name"]
    assert_equal 1, body["cards"][2]["quantity"]
    assert_nil body["cards"][2]["is_commander"]
  end

  test "GET /api/commanders/:id returns commander with empty cards array when no decklist" do
    commander = Commander.create!(
      name: "Commander Without Decklist",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )

    get api_path("/commanders/#{commander.id}")

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal commander.id, body["id"]
    assert_equal "Commander Without Decklist", body["name"]
    assert_equal 0, body["card_count"]
    assert_equal [], body["cards"]
  end

  test "GET /api/commanders/:id returns 404 when commander does not exist" do
    get api_path("/commanders/99999")

    assert_response :not_found
    body = JSON.parse(response.body)

    assert_equal "Commander not found", body["error"]
  end

  test "GET /api/commanders/:id returns 404 for invalid ID format" do
    get api_path("/commanders/invalid-id")

    assert_response :not_found
    body = JSON.parse(response.body)

    assert_equal "Commander not found", body["error"]
  end

  # ---------------------------------------------------------------------------
  # #show -- expanded card metadata for sorting/filtering
  # ---------------------------------------------------------------------------
  test "GET /api/commanders/:id includes expanded card metadata" do
    commander = Commander.create!(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )

    decklist = Decklist.create!(
      commander: commander,
      contents: [
        {
          "card_id" => "abc456-xyz8910",
          "card_name" => "Atraxa, Praetors' Voice",
          "card_url" => "https://scryfall.com/card/abc456",
          "quantity" => 1,
          "is_commander" => true,
          "card_type" => "Legendary Creature — Phyrexian Angel Horror",
          "rarity" => "mythic",
          "edh_rank" => 1,
          "release_date" => "2016-11-11",
          "usd_price" => "39.99"
        },
        {
          "card_id" => "abc123-def456",
          "card_name" => "Sol Ring",
          "card_url" => "https://scryfall.com/card/abc123",
          "quantity" => 1,
          "card_type" => "Artifact",
          "rarity" => "uncommon",
          "edh_rank" => 2,
          "release_date" => "2023-08-04",
          "usd_price" => "1.50"
        },
        {
          "card_id" => "xyz789-uvw012",
          "card_name" => "Command Tower",
          "card_url" => "https://scryfall.com/card/xyz789",
          "quantity" => 1,
          "card_type" => "Land",
          "rarity" => "common",
          "edh_rank" => 3,
          "release_date" => "2023-11-17",
          "usd_price" => "0.25"
        }
      ]
    )

    get api_path("/commanders/#{commander.id}")

    assert_response :success
    body = JSON.parse(response.body)

    # Verify first card (commander) has all metadata fields
    card = body["cards"][0]
    assert_equal "abc456-xyz8910", card["card_id"]
    assert_equal "Atraxa, Praetors' Voice", card["card_name"]
    assert_equal "https://scryfall.com/card/abc456", card["card_url"]
    assert_equal 1, card["quantity"]
    assert_equal true, card["is_commander"]
    assert_equal "Legendary Creature — Phyrexian Angel Horror", card["card_type"]
    assert_equal "mythic", card["rarity"]
    assert_equal 1, card["edh_rank"]
    assert_equal "2016-11-11", card["release_date"]
    assert_equal "39.99", card["usd_price"]

    # Verify second card has metadata
    card = body["cards"][1]
    assert_equal "Sol Ring", card["card_name"]
    assert_equal "Artifact", card["card_type"]
    assert_equal "uncommon", card["rarity"]
    assert_equal 2, card["edh_rank"]
    assert_equal "2023-08-04", card["release_date"]
    assert_equal "1.50", card["usd_price"]
  end

  test "GET /api/commanders/:id handles missing optional metadata gracefully" do
    commander = Commander.create!(
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test",
      last_scraped_at: Time.zone.parse("2026-02-02T02:00:00Z")
    )

    # Create decklist with cards missing optional metadata
    decklist = Decklist.create!(
      commander: commander,
      contents: [
        {
          "card_id" => "abc123",
          "card_name" => "Card With Minimal Data",
          "quantity" => 1,
          "is_commander" => true
          # Missing: card_type, rarity, edh_rank, release_date, usd_price, card_url
        },
        {
          "card_id" => "def456",
          "card_name" => "Card With Some Data",
          "quantity" => 1,
          "card_type" => "Creature",
          "usd_price" => "5.00"
          # Missing: rarity, edh_rank, release_date, card_url
        }
      ]
    )

    get api_path("/commanders/#{commander.id}")

    assert_response :success
    body = JSON.parse(response.body)

    # Verify first card with minimal data
    card = body["cards"][0]
    assert_equal "abc123", card["card_id"]
    assert_equal "Card With Minimal Data", card["card_name"]
    assert_equal 1, card["quantity"]
    assert_equal true, card["is_commander"]
    assert_nil card["card_type"]
    assert_nil card["rarity"]
    assert_nil card["edh_rank"]
    assert_nil card["release_date"]
    assert_nil card["usd_price"]
    assert_nil card["card_url"]

    # Verify second card with partial data
    card = body["cards"][1]
    assert_equal "Card With Some Data", card["card_name"]
    assert_equal "Creature", card["card_type"]
    assert_equal "5.00", card["usd_price"]
    assert_nil card["rarity"]
    assert_nil card["edh_rank"]
    assert_nil card["release_date"]
  end
end
