require "test_helper"

# ---------------------------------------------------------------------------
# Lightweight stand-in for MTG::Card objects returned by the SDK.
# Only exposes the attributes that CardSearchService reads.
# ---------------------------------------------------------------------------
MockCard = Struct.new(
  :id, :name, :set, :set_name, :number, :image_url, :border,
  keyword_init: true
)

class CardSearchIntegrationTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Scenario 1 -- search by name returns all printings with expected fields
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search returns formatted card results" do
    cards = [
      MockCard.new(id: 1001, name: "Lightning Bolt", set: "lea", set_name: "Limited Edition Alpha",
                   number: "157", image_url: "https://example.com/bolt1.jpg", border: "black"),
      MockCard.new(id: 1002, name: "Lightning Bolt", set: "m11", set_name: "Magic 2011",
                   number: "149", image_url: "https://example.com/bolt2.jpg", border: "black")
    ]

    stub_mtg_card(cards) do
      get "/api/cards/search", params: { q: "Lightning Bolt" }
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 2, body["cards"].size

    first = body["cards"].first
    assert_equal 1001, first["id"]
    assert_equal "Lightning Bolt", first["name"]
    assert_equal "lea", first["set"]
    assert_equal "Limited Edition Alpha", first["set_name"]
    assert_equal "157", first["collector_number"]
    assert_equal "https://example.com/bolt1.jpg", first["image_url"]
    assert_equal [], first["treatments"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 2 -- filter by single treatment
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search filters by single treatment" do
    cards = [
      MockCard.new(id: 2001, name: "Opt", set: "dom", set_name: "Dominaria",
                   number: "98", image_url: "https://example.com/opt1.jpg", border: "black"),
      MockCard.new(id: 2002, name: "Opt", set: "c20", set_name: "Commander 2020",
                   number: "72", image_url: "https://example.com/opt2.jpg", border: "borderless")
    ]

    stub_mtg_card(cards) do
      get "/api/cards/search", params: { q: "Opt", treatments: [ "borderless" ] }
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal 1, body["cards"].size
    assert_equal 2002, body["cards"].first["id"]
    assert_includes body["cards"].first["treatments"], "borderless"
  end

  # ---------------------------------------------------------------------------
  # Scenario 3 -- multiple treatment filters use OR logic
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search with multiple treatments uses OR logic" do
    cards = [
      MockCard.new(id: 3001, name: "Thoughtseize", set: "set_a", set_name: "Set A",
                   number: "1", image_url: "https://example.com/t1.jpg", border: "black"),
      MockCard.new(id: 3002, name: "Thoughtseize", set: "set_b", set_name: "Set B",
                   number: "2", image_url: "https://example.com/t2.jpg", border: "borderless"),
      MockCard.new(id: 3003, name: "Thoughtseize", set: "set_c", set_name: "Set C",
                   number: "3", image_url: "https://example.com/t3.jpg", border: "black")
    ]

    # Only borderless is derivable from current border field; foil is not yet
    # derivable so this card won't match.  The test verifies OR across the
    # treatments that *are* present.  Card 3002 matches "borderless"; neither
    # 3001 nor 3003 match either requested treatment.
    stub_mtg_card(cards) do
      get "/api/cards/search", params: { q: "Thoughtseize", treatments: [ "borderless", "foil" ] }
    end

    assert_response :success
    body = JSON.parse(response.body)

    # Only the borderless card matches (OR: borderless matches first filter)
    assert_equal 1, body["cards"].size
    assert_equal 3002, body["cards"].first["id"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 4 -- treatment filter with no matches returns empty array
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search returns empty cards array for non-matching treatment" do
    cards = [
      MockCard.new(id: 4001, name: "Giant Growth", set: "lea", set_name: "Limited Edition Alpha",
                   number: "200", image_url: "https://example.com/gg.jpg", border: "black")
    ]

    stub_mtg_card(cards) do
      get "/api/cards/search", params: { q: "Giant Growth", treatments: [ "borderless" ] }
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal [], body["cards"]
  end

  # ---------------------------------------------------------------------------
  # Scenario 6 -- performance: results returned within 500 ms
  # ---------------------------------------------------------------------------
  test "GET /api/cards/search completes within 500ms" do
    cards = [
      MockCard.new(id: 6001, name: "Counterspell", set: "lea", set_name: "Limited Edition Alpha",
                   number: "54", image_url: "https://example.com/counter.jpg", border: "black")
    ]

    elapsed_ms = nil
    stub_mtg_card(cards) do
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      get "/api/cards/search", params: { q: "Counterspell" }
      elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
    end

    assert_response :success
    assert elapsed_ms < 500, "Response took #{elapsed_ms.round(1)} ms (limit: 500 ms)"
  end

  # ---------------------------------------------------------------------------
  # Helper -- stubs MTG::Card.where to return a canned list without hitting
  # the network.  Yields the block so callers can make the request inside it.
  # ---------------------------------------------------------------------------
  private

  def stub_mtg_card(cards)
    fake_builder = Object.new
    fake_builder.define_singleton_method(:all) { cards }
    MTG::Card.stub(:where, fake_builder) { yield }
  end
end
