namespace :cards do
  desc "Update static card lists (Game Changers and Reserved List)"
  task update_static_lists: :environment do
    puts "=" * 80
    puts "Updating Static Card Lists"
    puts "=" * 80
    puts ""

    success = true

    # Fetch and write Game Changers list
    begin
      puts "Fetching Game Changers list from Wizards..."
      game_changers = CardListFetcher.fetch_game_changers
      CardListWriter.write("game_changers", game_changers, CardListFetcher::WIZARDS_GAME_CHANGERS_URL)
      puts "✓ Wrote #{game_changers.size} Game Changers to config/card_lists/game_changers.yml"
      puts ""
    rescue CardListFetcher::FetchError, CardListFetcher::ParseError, CardListWriter::WriteError => e
      puts "✗ Error fetching/writing Game Changers list:"
      puts "  #{e.class}: #{e.message}"
      puts "  NOTE: Game Changers list uses JavaScript rendering. Consider manual maintenance."
      puts "  See config/card_lists/game_changers.yml for current list."
      puts ""
      success = false
    end

    # Fetch and write Reserved List
    begin
      puts "Fetching Reserved List from Scryfall..."
      reserved_list = CardListFetcher.fetch_reserved_list
      CardListWriter.write("reserved_list", reserved_list, CardListFetcher::SCRYFALL_RESERVED_LIST_URL)
      puts "✓ Wrote #{reserved_list.size} cards to Reserved List (config/card_lists/reserved_list.yml)"
      puts ""
    rescue CardListFetcher::FetchError, CardListFetcher::ParseError, CardListWriter::WriteError => e
      puts "✗ Error fetching/writing Reserved List:"
      puts "  #{e.class}: #{e.message}"
      puts ""
      success = false
    end

    # Summary
    puts "=" * 80
    if success
      puts "Static lists updated successfully!"
      puts "=" * 80
      puts ""
    else
      puts "Task completed with errors. See messages above."
      puts "=" * 80
      puts ""
      exit 1
    end
  end
end
