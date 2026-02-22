namespace :analytics do
  desc "Show analytics summary"
  task summary: :environment do
    puts "=" * 80
    puts "Analytics Summary"
    puts "=" * 80
    puts ""
    puts "No analytics tasks configured."
    puts ""
  end
end
