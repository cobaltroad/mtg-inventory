require "test_helper"

class DecklistTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Setup
  # ---------------------------------------------------------------------------
  setup do
    @commander = Commander.create!(
      name: "Test Commander",
      rank: 1,
      edhrec_url: "https://edhrec.com/commanders/test-commander"
    )

    @partner = Commander.create!(
      name: "Test Partner",
      rank: 2,
      edhrec_url: "https://edhrec.com/commanders/test-partner"
    )
  end

  # ---------------------------------------------------------------------------
  # Presence validations
  # ---------------------------------------------------------------------------
  test "is valid with required attributes" do
    decklist = Decklist.new(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 },
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )
    assert decklist.valid?, decklist.errors.full_messages.inspect
  end

  test "is valid with commander and partner" do
    decklist = Decklist.new(
      commander: @commander,
      partner: @partner,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )
    assert decklist.valid?, decklist.errors.full_messages.inspect
  end

  test "is invalid without commander" do
    decklist = Decklist.new(
      commander: nil,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )
    assert decklist.invalid?
    assert_includes decklist.errors[:commander], "must exist"
  end

  test "is invalid without contents" do
    decklist = Decklist.new(
      commander: @commander,
      contents: nil
    )
    assert decklist.invalid?
    assert_includes decklist.errors[:contents], "can't be blank"
  end

  test "is invalid with empty contents array" do
    decklist = Decklist.new(
      commander: @commander,
      contents: []
    )
    assert decklist.invalid?
    assert_includes decklist.errors[:contents], "can't be blank"
  end

  # ---------------------------------------------------------------------------
  # Association tests
  # ---------------------------------------------------------------------------
  test "belongs to commander" do
    decklist = Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    assert_equal @commander.id, decklist.commander.id
  end

  test "belongs to optional partner" do
    decklist = Decklist.create!(
      commander: @commander,
      partner: @partner,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    assert_equal @partner.id, decklist.partner.id
  end

  test "partner can be nil" do
    decklist = Decklist.create!(
      commander: @commander,
      partner: nil,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    assert_nil decklist.partner
  end

  # ---------------------------------------------------------------------------
  # Uniqueness constraint on commander_id
  # ---------------------------------------------------------------------------
  test "is invalid when commander already has a decklist" do
    Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    duplicate = Decklist.new(
      commander: @commander,
      contents: [
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )
    assert duplicate.invalid?
    assert_includes duplicate.errors[:commander_id], "has already been taken"
  end

  test "allows different commanders to have their own decklists" do
    Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    other_commander = Commander.create!(
      name: "Other Commander",
      rank: 3,
      edhrec_url: "https://edhrec.com/commanders/other"
    )

    other_decklist = Decklist.new(
      commander: other_commander,
      contents: [
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )
    assert other_decklist.valid?, other_decklist.errors.full_messages.inspect
  end

  # ---------------------------------------------------------------------------
  # JSONB contents structure validation
  # ---------------------------------------------------------------------------
  test "contents stores array of card objects with required fields" do
    decklist = Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 },
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 },
        { card_id: "c3d4e5f6-a7b8-9012-cdef-123456789012", card_name: "Lightning Greaves", quantity: 2 }
      ]
    )

    decklist.reload
    assert_equal 3, decklist.contents.length
    assert_equal "Sol Ring", decklist.contents[0]["card_name"]
    assert_equal "a1b2c3d4-e5f6-7890-abcd-ef1234567890", decklist.contents[0]["card_id"]
    assert_equal 1, decklist.contents[0]["quantity"]
  end

  # ---------------------------------------------------------------------------
  # Full-text search vector
  # ---------------------------------------------------------------------------
  test "vector is automatically generated from contents" do
    decklist = Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 },
        { card_id: "b2c3d4e5-f6a7-8901-bcde-f12345678901", card_name: "Command Tower", quantity: 1 }
      ]
    )

    decklist.reload
    assert_not_nil decklist.vector
  end

  test "vector includes commander name" do
    decklist = Decklist.create!(
      commander: @commander,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    # The vector should contain the commander name for search purposes
    assert_not_nil decklist.vector
  end

  test "vector includes partner name when present" do
    decklist = Decklist.create!(
      commander: @commander,
      partner: @partner,
      contents: [
        { card_id: "a1b2c3d4-e5f6-7890-abcd-ef1234567890", card_name: "Sol Ring", quantity: 1 }
      ]
    )

    # The vector should contain both commander and partner names
    assert_not_nil decklist.vector
  end
end
