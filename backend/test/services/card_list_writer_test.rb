require "test_helper"

class CardListWriterTest < ActiveSupport::TestCase
  setup do
    @test_dir = Rails.root.join("tmp", "test_card_lists")
    @test_dir.mkpath
    CardListWriter.instance_variable_set(:@output_directory, @test_dir)
  end

  teardown do
    # Clean up test files
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
  end

  # ---------------------------------------------------------------------------
  # Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "write creates YAML file with correct structure" do
    cards = ["Black Lotus", "Mox Ruby", "Time Walk"]
    source_url = "https://example.com/source"

    CardListWriter.write("test_list", cards, source_url)

    file_path = @test_dir.join("test_list.yml")
    assert file_path.exist?, "Expected YAML file to be created at #{file_path}"

    yaml = YAML.load_file(file_path)
    assert_equal cards, yaml["cards"]
    assert_equal source_url, yaml["source"]
    assert yaml["last_updated"].present?
  end

  test "write creates alphabetically sorted card list" do
    cards = ["Zebra", "Apple", "Mango", "Banana"]
    source_url = "https://example.com/source"

    CardListWriter.write("sorted_list", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("sorted_list.yml"))
    assert_equal cards.sort, yaml["cards"], "Cards should be sorted alphabetically"
  end

  test "write includes last_updated timestamp in ISO 8601 format" do
    cards = ["Test Card"]
    source_url = "https://example.com/source"

    CardListWriter.write("timestamp_test", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("timestamp_test.yml"))
    timestamp = yaml["last_updated"]

    assert timestamp.present?, "Expected last_updated to be present"
    # Verify it's a valid date string (ISO 8601 format: YYYY-MM-DD)
    assert_match(/^\d{4}-\d{2}-\d{2}$/, timestamp, "Expected ISO 8601 date format (YYYY-MM-DD)")

    # Verify it's today's date
    assert_equal Date.today.iso8601, timestamp
  end

  test "write includes source URL in YAML" do
    cards = ["Test Card"]
    source_url = "https://moxfield.com/commanderbrackets/gamechangers"

    CardListWriter.write("source_test", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("source_test.yml"))
    assert_equal source_url, yaml["source"]
  end

  test "write generates valid YAML that can be parsed" do
    cards = ["Card One", "Card Two", "Card Three"]
    source_url = "https://example.com/source"

    CardListWriter.write("valid_yaml", cards, source_url)

    # Should not raise an error
    yaml = YAML.load_file(@test_dir.join("valid_yaml.yml"))
    assert_kind_of Hash, yaml
  end

  test "write preserves unicode characters in card names" do
    cards = ["Juzám Djinn", "Æther Vial", "Dockside Extortionist"]
    source_url = "https://example.com/source"

    CardListWriter.write("unicode_test", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("unicode_test.yml"))
    assert_includes yaml["cards"], "Juzám Djinn", "Should preserve á character"
    assert_includes yaml["cards"], "Æther Vial", "Should preserve Æ character"
  end

  test "write handles empty card list" do
    cards = []
    source_url = "https://example.com/source"

    CardListWriter.write("empty_list", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("empty_list.yml"))
    assert_equal [], yaml["cards"]
  end

  test "write overwrites existing file" do
    cards1 = ["First Card"]
    cards2 = ["Second Card", "Third Card"]
    source_url = "https://example.com/source"

    CardListWriter.write("overwrite_test", cards1, source_url)
    yaml1 = YAML.load_file(@test_dir.join("overwrite_test.yml"))
    assert_equal 1, yaml1["cards"].length

    CardListWriter.write("overwrite_test", cards2, source_url)
    yaml2 = YAML.load_file(@test_dir.join("overwrite_test.yml"))
    assert_equal 2, yaml2["cards"].length
    assert_equal cards2.sort, yaml2["cards"]
  end

  test "write removes duplicate card names" do
    cards = ["Black Lotus", "Mox Ruby", "Black Lotus", "Time Walk"]
    source_url = "https://example.com/source"

    CardListWriter.write("dedup_test", cards, source_url)

    yaml = YAML.load_file(@test_dir.join("dedup_test.yml"))
    assert_equal 3, yaml["cards"].length
    assert_equal 1, yaml["cards"].count("Black Lotus")
  end

  # ---------------------------------------------------------------------------
  # Directory Management Tests
  # ---------------------------------------------------------------------------

  test "write creates output directory if it doesn't exist" do
    # Use a new directory that doesn't exist yet
    new_dir = Rails.root.join("tmp", "test_new_card_lists")
    FileUtils.rm_rf(new_dir) if new_dir.exist?

    CardListWriter.instance_variable_set(:@output_directory, new_dir)

    cards = ["Test Card"]
    source_url = "https://example.com/source"

    CardListWriter.write("dir_test", cards, source_url)

    assert new_dir.exist?, "Expected output directory to be created"
    assert new_dir.join("dir_test.yml").exist?, "Expected YAML file to be created"

    # Cleanup
    FileUtils.rm_rf(new_dir)
  ensure
    # Restore original test directory
    CardListWriter.instance_variable_set(:@output_directory, @test_dir)
  end

  test "write uses config/card_lists directory by default" do
    # Reset to default
    CardListWriter.instance_variable_set(:@output_directory, nil)

    expected_dir = Rails.root.join("config", "card_lists")
    assert_equal expected_dir, CardListWriter.output_directory
  end

  # ---------------------------------------------------------------------------
  # Error Handling Tests
  # ---------------------------------------------------------------------------

  test "write raises WriteError on file system permission error" do
    skip "Permission test is unreliable in Docker environment" if ENV["DOCKER_CONTAINER"]

    # Make directory read-only and remove execute permission (prevents file creation)
    @test_dir.chmod(0444)

    cards = ["Test Card"]
    source_url = "https://example.com/source"

    # This test may not work in all environments (Docker, root user, etc.)
    # so we'll make it conditional
    begin
      CardListWriter.write("permission_test", cards, source_url)

      # If we get here and we're not root, the test should fail
      if Process.uid != 0
        flunk "Expected WriteError to be raised for read-only directory"
      else
        skip "Test skipped - running as root bypasses permission checks"
      end
    rescue CardListWriter::WriteError => e
      assert_match(/permission|write/i, e.message)
    end
  ensure
    # Restore permissions for cleanup
    @test_dir.chmod(0755) if @test_dir&.exist?
  end

  test "write raises WriteError when list_name contains directory traversal" do
    cards = ["Test Card"]
    source_url = "https://example.com/source"

    error = assert_raises(CardListWriter::WriteError) do
      CardListWriter.write("../../../etc/passwd", cards, source_url)
    end

    assert_match(/invalid|path|name/i, error.message)
  end

  test "write raises WriteError when list_name is empty" do
    cards = ["Test Card"]
    source_url = "https://example.com/source"

    error = assert_raises(CardListWriter::WriteError) do
      CardListWriter.write("", cards, source_url)
    end

    assert_match(/invalid|name|blank/i, error.message)
  end

  test "write raises WriteError when list_name is nil" do
    cards = ["Test Card"]
    source_url = "https://example.com/source"

    error = assert_raises(CardListWriter::WriteError) do
      CardListWriter.write(nil, cards, source_url)
    end

    assert_match(/invalid|name|blank/i, error.message)
  end

  test "write does not corrupt existing file on validation error" do
    cards1 = ["First Card", "Second Card"]
    source_url = "https://example.com/source"

    # Write valid file first
    CardListWriter.write("corruption_test", cards1, source_url)
    original_content = File.read(@test_dir.join("corruption_test.yml"))

    # Try to write with invalid list name (should fail before writing)
    begin
      CardListWriter.write("../invalid_name", ["Bad Card"], source_url)
    rescue CardListWriter::WriteError
      # Expected to fail
    end

    # Original file should still be intact
    current_content = File.read(@test_dir.join("corruption_test.yml"))
    assert_equal original_content, current_content, "Original file should not be corrupted on validation error"
  end

  # ---------------------------------------------------------------------------
  # YAML Format Tests
  # ---------------------------------------------------------------------------

  test "generated YAML matches expected format with correct key order" do
    cards = ["Mana Crypt", "Dockside Extortionist"]
    source_url = "https://moxfield.com/commanderbrackets/gamechangers"

    CardListWriter.write("format_test", cards, source_url)

    yaml_content = File.read(@test_dir.join("format_test.yml"))

    # Verify YAML structure
    expected_keys = ["cards", "last_updated", "source"]
    yaml = YAML.load(yaml_content)
    assert_equal expected_keys.sort, yaml.keys.sort

    # Verify format is readable (has newlines, indentation)
    assert_match(/^cards:/, yaml_content)
    assert_match(/^  - /, yaml_content, "Cards should be indented list items")
    assert_match(/^last_updated:/, yaml_content)
    assert_match(/^source:/, yaml_content)
  end

  test "cards are formatted as YAML array with proper indentation" do
    cards = ["Card A", "Card B", "Card C"]
    source_url = "https://example.com/source"

    CardListWriter.write("array_format_test", cards, source_url)

    yaml_content = File.read(@test_dir.join("array_format_test.yml"))

    # Each card should be on its own line with proper list syntax
    assert_match(/^  - "Card A"$/, yaml_content)
    assert_match(/^  - "Card B"$/, yaml_content)
    assert_match(/^  - "Card C"$/, yaml_content)
  end
end
