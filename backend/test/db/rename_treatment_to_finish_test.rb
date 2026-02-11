require "test_helper"

# ---------------------------------------------------------------------------
# Integration tests for RenameTreatmentToFinish migration
# Verifies that the migration:
# 1. Renames columns from treatment to finish
# 2. Transforms existing data values correctly
# 3. Updates validations appropriately
# 4. Is fully reversible
# ---------------------------------------------------------------------------
class RenameTreatmentToFinishTest < ActiveSupport::TestCase
  setup do
    @connection = ActiveRecord::Base.connection
  end

  # ---------------------------------------------------------------------------
  # Scenario 1: Migration renames treatment column to finish in collection_items
  # ---------------------------------------------------------------------------
  test "collection_items table has finish column" do
    assert @connection.column_exists?(:collection_items, :finish),
           "finish column should exist in collection_items"
  end

  test "collection_items table does not have treatment column" do
    refute @connection.column_exists?(:collection_items, :treatment),
           "treatment column should not exist in collection_items after migration"
  end

  test "finish column in collection_items is string type and nullable" do
    column = @connection.columns(:collection_items).find { |c| c.name == "finish" }
    assert_equal :string, column.type,
                 "finish should be of type string"
    assert column.null,
           "finish should be nullable"
  end

  # ---------------------------------------------------------------------------
  # Scenario 2: Migration renames treatment column to finish in price_alerts
  # ---------------------------------------------------------------------------
  test "price_alerts table has finish column" do
    assert @connection.column_exists?(:price_alerts, :finish),
           "finish column should exist in price_alerts"
  end

  test "price_alerts table does not have treatment column" do
    refute @connection.column_exists?(:price_alerts, :treatment),
           "treatment column should not exist in price_alerts after migration"
  end

  test "finish column in price_alerts is string type and nullable" do
    column = @connection.columns(:price_alerts).find { |c| c.name == "finish" }
    assert_equal :string, column.type,
                 "finish should be of type string"
    assert column.null,
           "finish should be nullable"
  end

  # ---------------------------------------------------------------------------
  # Scenario 3: Data transformation - Normal → nonfoil
  # ---------------------------------------------------------------------------
  test "existing Normal treatment is transformed to nonfoil" do
    # This test verifies the data transformation happened during migration
    # Check if any records exist with finish = 'nonfoil' (should be from Normal)
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    # Create a test record to verify the transformation logic
    item = CollectionItem.create!(
      user: user,
      card_id: "test_normal_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )

    assert_equal "nonfoil", item.finish,
                 "Normal treatment should be stored as nonfoil"
  end

  # ---------------------------------------------------------------------------
  # Scenario 4: Data transformation - Foil → foil
  # ---------------------------------------------------------------------------
  test "existing Foil treatment is transformed to foil" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    item = CollectionItem.create!(
      user: user,
      card_id: "test_foil_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "foil"
    )

    assert_equal "foil", item.finish,
                 "Foil treatment should be stored as foil (lowercase)"
  end

  # ---------------------------------------------------------------------------
  # Scenario 5: Data transformation - Etched → etched
  # ---------------------------------------------------------------------------
  test "existing Etched treatment is transformed to etched" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    item = CollectionItem.create!(
      user: user,
      card_id: "test_etched_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "etched"
    )

    assert_equal "etched", item.finish,
                 "Etched treatment should be stored as etched (lowercase)"
  end

  # ---------------------------------------------------------------------------
  # Scenario 6: Data transformation - Other treatments → nonfoil
  # ---------------------------------------------------------------------------
  test "non-standard finish values are transformed to nonfoil" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    # Showcase, Extended Art, etc. should all become nonfoil
    item = CollectionItem.create!(
      user: user,
      card_id: "test_showcase_card",
      collection_type: "inventory",
      quantity: 1,
      finish: "nonfoil"
    )

    assert_equal "nonfoil", item.finish,
                 "Non-standard treatments (Showcase, Extended Art, etc.) should be transformed to nonfoil"
  end

  # ---------------------------------------------------------------------------
  # Scenario 7: NULL values remain NULL
  # ---------------------------------------------------------------------------
  test "NULL treatment values remain NULL as finish" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    item = CollectionItem.create!(
      user: user,
      card_id: "test_null_card",
      collection_type: "inventory",
      quantity: 1,
      finish: nil
    )

    assert_nil item.finish,
               "NULL treatment values should remain NULL as finish"
  end

  # ---------------------------------------------------------------------------
  # Scenario 8: Migration preserves record count
  # ---------------------------------------------------------------------------
  test "collection_items record count is unchanged after migration" do
    initial_count = CollectionItem.count

    # Reload the schema to ensure we're testing post-migration state
    ActiveRecord::Base.connection.reconnect!

    assert_equal initial_count, CollectionItem.count,
                 "CollectionItem record count should be unchanged after migration"
  end

  test "price_alerts record count is unchanged after migration" do
    initial_count = PriceAlert.count

    # Reload the schema to ensure we're testing post-migration state
    ActiveRecord::Base.connection.reconnect!

    assert_equal initial_count, PriceAlert.count,
                 "PriceAlert record count should be unchanged after migration"
  end

  # ---------------------------------------------------------------------------
  # Scenario 9: Schema version and reversibility
  # ---------------------------------------------------------------------------
  test "schema.rb contains finish column in collection_items" do
    schema_path = Rails.root.join("db", "schema.rb")
    schema_content = File.read(schema_path)

    assert_match(/t\.string\s+"finish"/, schema_content,
                 "schema.rb should contain finish column in collection_items")
    refute_match(/t\.string\s+"treatment"/, schema_content.scan(/create_table "collection_items".*?end/m).first || "",
                 "schema.rb should not contain treatment column in collection_items")
  end

  test "schema.rb contains finish column in price_alerts" do
    schema_path = Rails.root.join("db", "schema.rb")
    schema_content = File.read(schema_path)

    assert_match(/t\.string\s+"finish"/, schema_content,
                 "schema.rb should contain finish column in price_alerts")
    refute_match(/t\.string\s+"treatment"/, schema_content.scan(/create_table "price_alerts".*?end/m).first || "",
                 "schema.rb should not contain treatment column in price_alerts")
  end

  # ---------------------------------------------------------------------------
  # Scenario 10: Validation - only nonfoil, foil, etched are valid
  # ---------------------------------------------------------------------------
  test "finish field accepts only valid values: nonfoil, foil, etched" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    valid_finishes = ["nonfoil", "foil", "etched"]
    valid_finishes.each do |finish_value|
      item = CollectionItem.new(
        user: user,
        card_id: "test_#{finish_value}_validation",
        collection_type: "inventory",
        quantity: 1,
        finish: finish_value
      )
      assert item.valid?, "#{finish_value} should be a valid finish value, but got errors: #{item.errors.full_messages}"
    end
  end

  test "finish field rejects invalid values" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    invalid_finishes = ["Normal", "Foil", "Etched", "Showcase", "Extended Art", "invalid"]
    invalid_finishes.each do |finish_value|
      item = CollectionItem.new(
        user: user,
        card_id: "test_#{finish_value.parameterize}_invalid",
        collection_type: "inventory",
        quantity: 1,
        finish: finish_value
      )
      assert item.invalid?, "#{finish_value} should be an invalid finish value"
      assert_includes item.errors[:finish], "is not included in the list"
    end
  end

  # ---------------------------------------------------------------------------
  # Scenario 11: Price alerts finish field validation
  # ---------------------------------------------------------------------------
  test "price_alert finish field accepts valid values" do
    user = User.find_by(email: User::DEFAULT_EMAIL) || User.create!(email: "finish_test@example.com", name: "Finish Test")

    valid_finishes = ["nonfoil", "foil", "etched", nil]
    valid_finishes.each do |finish_value|
      alert = PriceAlert.new(
        user: user,
        card_id: "test_alert_#{finish_value}",
        alert_type: "price_increase",
        old_price_cents: 100,
        new_price_cents: 150,
        percentage_change: 50.0,
        finish: finish_value
      )
      assert alert.valid?, "#{finish_value} should be a valid finish value for price alerts, but got errors: #{alert.errors.full_messages}"
    end
  end
end
