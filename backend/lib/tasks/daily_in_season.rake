namespace :daily_in_season do
  desc "Run the daily in-season sync sequence. Usage: DATE=2026-08-13 bin/rails daily_in_season:sync"
  task sync: :environment do
    date = ENV["DATE"].presence
    start_date = ENV["START_DATE"].presence || date || Date.yesterday.iso8601
    end_date = ENV["END_DATE"].presence || date || start_date
    season = ENV["SEASON"].presence

    puts "Starting daily in-season refresh for #{start_date} through #{end_date}..."
    $stdout.flush

    result = DailyInSeasonSync.call(start_date: start_date, end_date: end_date, season: season)
    abort result[:message] unless result[:success]

    result.dig(:data, :stages).each { |stage| puts "✓ #{stage[:name]}: #{stage[:message]}" }
    puts result[:message]
  end
end
