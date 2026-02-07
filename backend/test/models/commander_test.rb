require "test_helper"

class CommanderTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with all required attributes" do
    commander = Commander.new(
      name: "Atraxa, Praetors' Voice",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/atraxa-praetors-voice"
    )
    assert commander.valid?, commander.errors.full_messages.inspect
  end

  test "is invalid without name" do
    commander = Commander.new(
      name: "",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test"
    )
    assert commander.invalid?
    assert_includes commander.errors[:name], "can't be blank"
  end

  test "is invalid when name is nil" do
    commander = Commander.new(
      name: nil,
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test"
    )
    assert commander.invalid?
    assert_includes commander.errors[:name], "can't be blank"
  end

  test "is invalid without rank" do
    commander = Commander.new(
      name: "Test Commander",
      rank: nil,
      edhrec_url: "https://edhrec.com/commanders/test"
    )
    assert commander.invalid?
    assert_includes commander.errors[:rank], "can't be blank"
  end

  test "is invalid without edhrec_url" do
    commander = Commander.new(
      name: "Test Commander",
      rank: 1,
      edhrec_url: ""
    )
    assert commander.invalid?
    assert_includes commander.errors[:edhrec_url], "can't be blank"
  end

  test "is invalid when edhrec_url is nil" do
    commander = Commander.new(
      name: "Test Commander",
      rank: 1,
      edhrec_url: nil
    )
    assert commander.invalid?
    assert_includes commander.errors[:edhrec_url], "can't be blank"
  end

  # ---------------------------------------------------------------------------
  # Uniqueness constraint on name
  # ---------------------------------------------------------------------------
  test "is invalid when another commander already has that name" do
    Commander.create!(
      name: "Unique Commander",
      rank: 5,
      edhrec_url: "https://edhrec.com/commanders/unique"
    )

    duplicate = Commander.new(
      name: "Unique Commander",
      rank: 10,
      edhrec_url: "https://edhrec.com/commanders/unique-2"
    )
    assert duplicate.invalid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "allows two commanders with different names" do
    Commander.create!(
      name: "First Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/first"
    )

    second = Commander.new(
      name: "Second Commander",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/second"
    )
    assert second.valid?, second.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Optional last_scraped_at field
  # ---------------------------------------------------------------------------
  test "is valid with last_scraped_at set" do
    commander = Commander.new(
      name: "Scraped Commander",
      rank: 3,
      edhrec_url: "https://edhrec.com/commanders/scraped",
      last_scraped_at: Time.current
    )
    assert commander.valid?, commander.errors.full_messages.inspect
  end

  test "is valid with nil last_scraped_at" do
    commander = Commander.new(
      name: "Unscraped Commander",
      rank: 4,
      edhrec_url: "https://edhrec.com/commanders/unscraped",
      last_scraped_at: nil
    )
    assert commander.valid?, commander.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # Association with decklists
  # ---------------------------------------------------------------------------
  test "has many decklists association" do
    commander = Commander.create!(
      name: "Associated Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/associated"
    )

    assert_respond_to commander, :decklists
  end

  test "commander can have multiple decklists with different partners" do
    commander = Commander.create!(
      name: "Multi Deck Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/multi"
    )

    partner1 = Commander.create!(
      name: "Partner One",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/partner1"
    )

    partner2 = Commander.create!(
      name: "Partner Two",
      rank: 3,
      edhrec_url: "https://edhrec.com/commanders/partner2"
    )

    # Solo decklist
    solo_deck = Decklist.create!(
      commander: commander,
      partner: nil,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    # Partner decklist 1
    partner_deck1 = Decklist.create!(
      commander: commander,
      partner: partner1,
      contents: [
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )

    # Partner decklist 2
    partner_deck2 = Decklist.create!(
      commander: commander,
      partner: partner2,
      contents: [
        { card_id: "c3d4e5f6-a7b8-9012-cdef-123456789012", card_name: "Arcane Signet", quantity: 1 }
      ]
    )

    assert_equal 3, commander.decklists.count
    assert_includes commander.decklists, solo_deck
    assert_includes commander.decklists, partner_deck1
    assert_includes commander.decklists, partner_deck2
  end

  test "destroying commander cascades to all decklists" do
    commander = Commander.create!(
      name: "Cascade Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/cascade"
    )

    partner = Commander.create!(
      name: "Cascade Partner",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/cascade-partner"
    )

    # Create two decklists for this commander
    Decklist.create!(
      commander: commander,
      partner: nil,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    Decklist.create!(
      commander: commander,
      partner: partner,
      contents: [
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )

    assert_difference "Decklist.count", -2 do
      commander.destroy
    end
  end
end
