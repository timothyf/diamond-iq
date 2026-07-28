namespace :daily_analytics do
  desc "Backfill daily analytics for every date with imported MLB game details (YEAR is optional)"
  task backfill_game_details: :environment do
    scope = Game.joins(:game_player_pitching_lines)
    if ENV["YEAR"].present?
      year = Integer(ENV["YEAR"], exception: false)
      abort "YEAR must be a four-digit season" unless year&.between?(1876, 9999)

      scope = scope.where(official_date: Date.new(year, 1, 1)..Date.new(year, 12, 31))
    end

    dates = scope
      .distinct
      .order(:official_date)
      .pluck(:official_date)

    abort "No imported MLB game-detail dates were found" if dates.empty?

    result = DailyAnalyticsRefresh.call(dates: dates)
    abort result[:message] unless result[:success]

    puts result[:message]
    puts "Coverage: #{dates.first.iso8601} through #{dates.last.iso8601}"
    puts "Calculation version: #{result.dig(:data, :calculation_version)}"
    result.dig(:data, :row_counts).each { |table, count| puts "#{table}: #{count}" }
  end

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

  desc "Refresh persisted player trend events through AS_OF (defaults to latest pitch date)"
  task :refresh_trend_events, [ :as_of ] => :environment do |_task, args|
    as_of = args[:as_of].presence || ENV["AS_OF"].presence
    parsed_as_of = as_of.present? ? Date.iso8601(as_of) : nil
    mlb_ids = PitchDatum.where.not(pitcher: nil).distinct.pluck(:pitcher) |
      PitchDatum.where.not(batter: nil).distinct.pluck(:batter)
    result = PlayerTrendEventRefresh.call(players: Player.where(mlb_id: mlb_ids), as_of: parsed_as_of)
    abort result[:message] unless result[:success]

    counts = result.fetch(:data)
    puts "Trend events refreshed for #{counts.fetch(:players)} players"
    puts "Created: #{counts.fetch(:created)}, updated: #{counts.fetch(:updated)}, resolved: #{counts.fetch(:resolved)}"
  rescue Date::Error
    abort "AS_OF must be a valid ISO date"
  end
end
