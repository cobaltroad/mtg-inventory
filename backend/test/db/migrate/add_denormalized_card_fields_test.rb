require "test_helper"

class AddDenormalizedCardFieldsTest < ActiveSupport::TestCase
  def setup
    # Ensure test database has seeded users
    User.delete_all
    load Rails.root.join("db", "seeds.rb")
    @user = User.find_by!(email: User::DEFAULT_EMAIL)
  end

  test "migration adds card_name column" do
    assert CollectionItem.column_names.include?("card_name"),
           "Expected card_name column to exist in collection_items table"

    column = CollectionItem.columns.find { |c| c.name == "card_name" }
    assert_equal :string, column.type, "card_name should be a string column"
  end

  test "migration adds set_name column" do
    assert CollectionItem.column_names.include?("set_name"),
           "Expected set_name column to exist in collection_items table"

    column = CollectionItem.columns.find { |c| c.name == "set_name" }
    assert_equal :string, column.type, "set_name should be a string column"
  end

  test "migration adds released_at column" do
    assert CollectionItem.column_names.include?("released_at"),
           "Expected released_at column to exist in collection_items table"

    column = CollectionItem.columns.find { |c| c.name == "released_at" }
    assert_equal :date, column.type, "released_at should be a date column"
  end

  test "migration adds index on card_name" do
    indexes = ActiveRecord::Base.connection.indexes(:collection_items)
    card_name_index = indexes.find { |i| i.columns.include?("card_name") }

    assert card_name_index, "Expected index on card_name column"
  end

  test "migration adds index on set_name" do
    indexes = ActiveRecord::Base.connection.indexes(:collection_items)
    set_name_index = indexes.find { |i| i.columns.include?("set_name") }

    assert set_name_index, "Expected index on set_name column"
  end

  test "migration adds index on released_at" do
    indexes = ActiveRecord::Base.connection.indexes(:collection_items)
    released_at_index = indexes.find { |i| i.columns.include?("released_at") }

    assert released_at_index, "Expected index on released_at column"
  end

  test "denormalized columns allow null values initially for backward compatibility" do
    # Create item without denormalized fields
    item = CollectionItem.new(
      user: @user,
      card_id: "test_null_fields",
      collection_type: "inventory",
      quantity: 1
    )

    # Should be able to save with nil denormalized fields
    assert item.valid?, "Item should be valid even with nil denormalized fields"
  end
end
