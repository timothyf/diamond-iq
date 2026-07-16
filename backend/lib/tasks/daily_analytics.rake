namespace :daily_analytics do
  desc "Refresh versioned daily analytics summaries (VERSION defaults to the current calculation version)"
  task :refresh, [ :start_date, :end_date ] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    version = ENV["VERSION"].presence || DailyAnalyticsRefresh::CALCULATION_VERSION

    abort "Usage: bin/rails 'daily_analytics:refresh[YYYY-MM-DD,YYYY-MM-DD]'" if start_date.blank?

    result = DailyAnalyticsRefresh.call(
      start_date: start_date,
      end_date: end_date,
      calculation_version: version
    )
    abort result[:message] unless result[:success]

    puts result[:message]
    puts "Calculation version: #{result.dig(:data, :calculation_version)}"
    result.dig(:data, :row_counts).each { |table, count| puts "#{table}: #{count}" }
  end
end
