# frozen_string_literal: true

require "test_helper"
require "rake"

class MaintenanceRakeTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Create test user for collection items
    @user = User.create!(email: "rake_test@example.com", name: "Rake Test User")
  end

  teardown do
    # Clean up any test data
    CollectionItem.where(user: @user).destroy_all
    CardPrice.where("card_id LIKE '%test%' OR card_id LIKE '%debug%' OR card_id LIKE '%mock%'").destroy_all
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup removes test card IDs from collection_items
  # ---------------------------------------------------------------------------
  test "jobs:maintenance:cleanup:test_data removes collection items with test card IDs" do
    # Create legitimate item
    legitimate_item = CollectionItem.create!(
      user: @user,
      card_id: "abc123-real-card",
      collection_type: "inventory",
      quantity: 1
    )

    # Create test items that should be removed
    test_item = CollectionItem.create!(
      user: @user,
      card_id: "test-card-debug",
      collection_type: "inventory",
      quantity: 1
    )

    debug_item = CollectionItem.create!(
      user: @user,
      card_id: "debug-card-123",
      collection_type: "wishlist",
      quantity: 2
    )

    mock_item = CollectionItem.create!(
      user: @user,
      card_id: "mock-card-456",
      collection_type: "inventory",
      quantity: 3
    )

    # Verify initial state
    assert_equal 4, CollectionItem.where(user: @user).count

    # Run cleanup task (suppress output)
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    # Verify test items were removed
    assert CollectionItem.exists?(legitimate_item.id), "Legitimate item should remain"
    refute CollectionItem.exists?(test_item.id), "Test item should be removed"
    refute CollectionItem.exists?(debug_item.id), "Debug item should be removed"
    refute CollectionItem.exists?(mock_item.id), "Mock item should be removed"

    # Verify only legitimate item remains
    assert_equal 1, CollectionItem.where(user: @user).count
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup removes card_prices with test card IDs
  # ---------------------------------------------------------------------------
  test "cleanup:test_data removes card prices with test card IDs" do
    # Create legitimate price
    legitimate_price = CardPrice.create!(
      card_id: "xyz789-real-card",
      fetched_at: Time.current,
      usd_cents: 100
    )

    # Create test prices that should be removed
    test_price = CardPrice.create!(
      card_id: "test-card-debug",
      fetched_at: Time.current,
      usd_cents: 130
    )

    debug_price = CardPrice.create!(
      card_id: "debug-price-card",
      fetched_at: Time.current,
      usd_cents: 200
    )

    mock_price = CardPrice.create!(
      card_id: "mock-card-789",
      fetched_at: Time.current,
      usd_cents: 150
    )

    # Verify initial state
    initial_count = CardPrice.count
    assert initial_count >= 4

    # Run cleanup task (suppress output)
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    # Verify test prices were removed
    assert CardPrice.exists?(legitimate_price.id), "Legitimate price should remain"
    refute CardPrice.exists?(test_price.id), "Test price should be removed"
    refute CardPrice.exists?(debug_price.id), "Debug price should be removed"
    refute CardPrice.exists?(mock_price.id), "Mock price should be removed"

    # Verify correct number of records deleted
    assert_equal initial_count - 3, CardPrice.count
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup is case-insensitive
  # ---------------------------------------------------------------------------
  test "cleanup:test_data removes card IDs with mixed case test keywords" do
    # Create items with various case patterns
    CollectionItem.create!(
      user: @user,
      card_id: "TEST-card-uppercase",
      collection_type: "inventory",
      quantity: 1
    )

    CollectionItem.create!(
      user: @user,
      card_id: "card-TeSt-mixedcase",
      collection_type: "inventory",
      quantity: 1
    )

    CardPrice.create!(
      card_id: "DEBUG-CARD",
      fetched_at: Time.current,
      usd_cents: 100
    )

    CardPrice.create!(
      card_id: "MoCk-CaRd",
      fetched_at: Time.current,
      usd_cents: 100
    )

    initial_items = CollectionItem.where(user: @user).count
    initial_prices = CardPrice.count

    # Run cleanup task (suppress output)
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    # Verify all test data removed regardless of case
    assert_equal initial_items - 2, CollectionItem.where(user: @user).count
    assert_equal initial_prices - 2, CardPrice.count
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup handles empty database gracefully
  # ---------------------------------------------------------------------------
  test "jobs:maintenance:cleanup:test_data handles empty database without errors" do
    # Clear all test data first
    CollectionItem.where(user: @user).destroy_all
    CardPrice.destroy_all

    # Should not raise error on empty database
    assert_nothing_raised do
      silence_stream($stdout) do
        Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
        Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup is idempotent (can run multiple times safely)
  # ---------------------------------------------------------------------------
  test "jobs:maintenance:cleanup:test_data is idempotent" do
    # Create test data
    CollectionItem.create!(
      user: @user,
      card_id: "test-idempotent",
      collection_type: "inventory",
      quantity: 1
    )

    CardPrice.create!(
      card_id: "test-idempotent",
      fetched_at: Time.current,
      usd_cents: 100
    )

    # Run cleanup first time
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    first_run_items = CollectionItem.where(user: @user).count
    first_run_prices = CardPrice.count

    # Run cleanup second time
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    second_run_items = CollectionItem.where(user: @user).count
    second_run_prices = CardPrice.count

    # Verify counts unchanged (idempotent)
    assert_equal first_run_items, second_run_items
    assert_equal first_run_prices, second_run_prices
  end

  # ---------------------------------------------------------------------------
  # Test: Cleanup detects additional test keywords (fixture, sample, dummy)
  # ---------------------------------------------------------------------------
  test "cleanup:test_data removes cards with additional test keywords" do
    # Create items with various test-related keywords
    CollectionItem.create!(
      user: @user,
      card_id: "fixture-card-123",
      collection_type: "inventory",
      quantity: 1
    )

    CollectionItem.create!(
      user: @user,
      card_id: "sample-card-456",
      collection_type: "inventory",
      quantity: 1
    )

    CollectionItem.create!(
      user: @user,
      card_id: "dummy-card-789",
      collection_type: "inventory",
      quantity: 1
    )

    initial_count = CollectionItem.where(user: @user).count
    assert initial_count >= 3

    # Run cleanup task (suppress output)
    silence_stream($stdout) do
      Rake::Task["jobs:maintenance:cleanup:test_data"].reenable
      Rake::Task["jobs:maintenance:cleanup:test_data"].invoke
    end

    # Verify all test-related items removed
    assert_equal 0, CollectionItem.where(user: @user).count
  end

  private

  # Helper to suppress output during rake task execution
  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(IO::NULL)
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end
end
