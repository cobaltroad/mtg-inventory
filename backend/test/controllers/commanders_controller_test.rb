require "test_helper"

class CommandersControllerTest < ActionDispatch::IntegrationTest
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
end
