namespace :prices do
  desc "Update prices for all cards in inventory and wishlist"
  task update: :environment do
    puts "Starting manual price update..."
    puts "This will fetch current prices for all unique cards in your collections."

    # Count cards before starting
    card_count = CollectionItem.distinct.count(:card_id)
    puts "Found #{card_count} unique cards to process."

    if card_count.zero?
      puts "No cards found. Add some cards to your inventory first."
      exit 0
    end

    # Run the job synchronously
    UpdateCardPricesJob.perform_now

    puts "Price update complete!"
    puts "Run this command anytime to refresh prices manually."
  end
end
