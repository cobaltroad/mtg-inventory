namespace :commanders do
  desc "Scrape top commanders and decklists from EDHREC"
  task scrape: :environment do
    puts "Starting EDHREC commander scrape..."
    puts "This will fetch the top 20 commanders and their average decklists."

    # Show current commander count
    commander_count = Commander.count
    puts "Current commanders in database: #{commander_count}"

    # Run the job synchronously
    puts "\nFetching commanders from EDHREC..."
    ScrapeEdhrecCommandersJob.perform_now

    # Show updated count
    new_count = Commander.count
    puts "\nScrape complete!"
    puts "Commanders in database: #{new_count} (#{new_count - commander_count} new)"
    puts "\nThis job runs automatically every Sunday at 8am UTC in production."
    puts "In development, it runs daily at 8am for testing."
  end
end
