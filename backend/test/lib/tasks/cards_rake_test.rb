require "test_helper"
require "rake"
require "webmock/minitest"

class CardsRakeTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    # Clear and reenable task
    if Rake::Task.task_defined?("cards:update_static_lists")
      Rake::Task["cards:update_static_lists"].reenable
    end

    WebMock.reset!
    RateLimiter.clear_all_state

    # Use test directory for output
    @test_dir = Rails.root.join("tmp", "test_card_lists_rake")
    @test_dir.mkpath
    CardListWriter.instance_variable_set(:@output_directory, @test_dir)

    # Stub API requests
    stub_wizards_game_changers
    stub_scryfall_reserved_list
  end

  teardown do
    # Clean up test files
    FileUtils.rm_rf(@test_dir) if @test_dir.exist?
    # Reset to default
    CardListWriter.instance_variable_set(:@output_directory, nil)
  end

  # ---------------------------------------------------------------------------
  # Basic Functionality Tests
  # ---------------------------------------------------------------------------

  test "update_static_lists task creates game_changers.yml file" do
    capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end

    file_path = @test_dir.join("game_changers.yml")
    assert file_path.exist?, "Expected game_changers.yml to be created"

    yaml = YAML.load_file(file_path)
    assert_kind_of Array, yaml["cards"]
    assert_operator yaml["cards"].length, :>, 0
    assert_equal Date.today.iso8601, yaml["last_updated"]
    assert_equal CardListFetcher::WIZARDS_GAME_CHANGERS_URL, yaml["source"]
  end

  test "update_static_lists task creates reserved_list.yml file" do
    capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end

    file_path = @test_dir.join("reserved_list.yml")
    assert file_path.exist?, "Expected reserved_list.yml to be created"

    yaml = YAML.load_file(file_path)
    assert_kind_of Array, yaml["cards"]
    assert_operator yaml["cards"].length, :>, 0
    assert_equal Date.today.iso8601, yaml["last_updated"]
    assert_match(/scryfall\.com/, yaml["source"])
  end

  test "update_static_lists task prints progress messages" do
    output = capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end.join

    assert_match(/Fetching Game Changers/i, output)
    assert_match(/Wrote.*Game Changers/i, output)
    assert_match(/Fetching Reserved List/i, output)
    assert_match(/Wrote.*Reserved List/i, output)
    assert_match(/Static lists updated successfully/i, output)
  end

  test "update_static_lists task prints card counts" do
    output = capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end.join

    # Should show count of cards written
    assert_match(/\d+ .*Game Changers/i, output)
    assert_match(/\d+ cards.*Reserved List/i, output)
  end

  test "update_static_lists task creates directory if it doesn't exist" do
    # Remove directory
    FileUtils.rm_rf(@test_dir)
    refute @test_dir.exist?, "Test directory should not exist before task runs"

    capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end

    assert @test_dir.exist?, "Expected task to create output directory"
  end

  test "update_static_lists task is idempotent" do
    # Run twice
    capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end

    first_gc_content = File.read(@test_dir.join("game_changers.yml"))
    first_rl_content = File.read(@test_dir.join("reserved_list.yml"))

    Rake::Task["cards:update_static_lists"].reenable
    stub_wizards_game_changers  # Re-stub since WebMock stubs are consumed
    stub_scryfall_reserved_list

    capture_io do
      Rake::Task["cards:update_static_lists"].invoke
    end

    second_gc_content = File.read(@test_dir.join("game_changers.yml"))
    second_rl_content = File.read(@test_dir.join("reserved_list.yml"))

    # Files should have same content (except possibly timestamp)
    assert_equal first_gc_content, second_gc_content, "game_changers.yml should be identical"
    assert_equal first_rl_content, second_rl_content, "reserved_list.yml should be identical"
  end

  # ---------------------------------------------------------------------------
  # Error Handling Tests
  # ---------------------------------------------------------------------------

  test "update_static_lists task handles Moxfield network failure gracefully" do
    # Override stub to return error
    WebMock.reset!
    stub_request(:get, CardListFetcher::WIZARDS_GAME_CHANGERS_URL)
      .to_timeout

    stub_scryfall_reserved_list

    output = capture_io do
      assert_raises(SystemExit) do
        Rake::Task["cards:update_static_lists"].invoke
      end
    end.join

    assert_match(/error|failed/i, output)
    assert_match(/Game Changers/i, output)
  end

  test "update_static_lists task handles Scryfall network failure gracefully" do
    # Override stub to return error
    WebMock.reset!
    stub_wizards_game_changers

    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_timeout

    output = capture_io do
      assert_raises(SystemExit) do
        Rake::Task["cards:update_static_lists"].invoke
      end
    end.join

    assert_match(/error|failed/i, output)
    assert_match(/Reserved List/i, output)
  end

  test "update_static_lists task continues if one list succeeds and one fails" do
    # Make Reserved List fail, but Game Changers succeed
    WebMock.reset!
    stub_wizards_game_changers

    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 500, body: "Server Error")

    output = capture_io do
      assert_raises(SystemExit) do
        Rake::Task["cards:update_static_lists"].invoke
      end
    end.join

    # Game Changers should have been written
    assert @test_dir.join("game_changers.yml").exist?, "Game Changers file should exist even if Reserved List failed"

    # But Reserved List should not exist
    refute @test_dir.join("reserved_list.yml").exist?, "Reserved List file should not exist after failure"
  end

  private

  # ---------------------------------------------------------------------------
  # Test Helpers - API Stubs
  # ---------------------------------------------------------------------------

  def stub_wizards_game_changers
    html = build_moxfield_html([
      "Dockside Extortionist",
      "Jeweled Lotus",
      "Mana Crypt",
      "Mana Vault",
      "Sol Ring"
    ])

    stub_request(:get, CardListFetcher::WIZARDS_GAME_CHANGERS_URL)
      .to_return(status: 200, body: html, headers: { "Content-Type" => "text/html" })
  end

  def stub_scryfall_reserved_list
    json = build_scryfall_json([
      "Black Lotus",
      "Gaea's Cradle",
      "Lion's Eye Diamond",
      "Mox Ruby",
      "Time Walk"
    ])

    stub_request(:get, %r{https://api\.scryfall\.com/cards/search\?q=is:reserved})
      .to_return(status: 200, body: json, headers: { "Content-Type" => "application/json" })
  end

  def build_moxfield_html(card_names)
    cards_html = card_names.map do |name|
      %(<div class="card-name">#{name}</div>)
    end.join("\n")

    <<~HTML
      <html>
      <head><title>Game Changers - Moxfield</title></head>
      <body>
        <div class="card-list">
          #{cards_html}
        </div>
      </body>
      </html>
    HTML
  end

  def build_scryfall_json(card_names)
    cards = card_names.map do |name|
      {
        id: SecureRandom.uuid,
        name: name,
        object: "card"
      }
    end

    {
      object: "list",
      total_cards: cards.length,
      has_more: false,
      data: cards
    }.to_json
  end
end
