namespace :contextual_benchmarks do
  desc "Refresh cached MLB, position, role, and player-percentile context for a date range"
  task :refresh, [ :start_date, :end_date ] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    version = ENV["VERSION"].presence || DailyAnalyticsRefresh::CALCULATION_VERSION

    abort "Usage: bin/rails 'contextual_benchmarks:refresh[YYYY-MM-DD,YYYY-MM-DD]'" if start_date.blank?

    result = ContextualBenchmarkRefresh.call(
      start_date: start_date,
      end_date: end_date,
      calculation_version: version
    )
    abort result[:message] unless result[:success]

    puts result[:message]
    puts "Benchmarks: #{result.dig(:data, :benchmark_count)}"
    puts "Player percentiles: #{result.dig(:data, :percentile_count)}"
  end
end
