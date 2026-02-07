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
  # Association with decklist
  # ---------------------------------------------------------------------------
  test "has one decklist association" do
    commander = Commander.create!(
      name: "Associated Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/associated"
    )

    assert_respond_to commander, :decklist
  end

  test "destroying commander cascades to decklist" do
    commander = Commander.create!(
      name: "Cascade Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/cascade"
    )

    decklist = Decklist.create!(
      commander: commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    assert_difference "Decklist.count", -1 do
      commander.destroy
    end
  end
end
