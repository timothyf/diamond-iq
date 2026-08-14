class DailyInSeasonSync
  GAME_TYPES = "R"

  def self.call(start_date:, end_date: start_date, season: nil)
    new(start_date: start_date, end_date: end_date, season: season).call
  end

  def initialize(start_date:, end_date:, season: nil)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @season = Integer(season || @end_date&.year, exception: false)
  end

  def call
    return failure("Start date and end date must be valid ISO dates") if start_date.nil? || end_date.nil?
    return failure("End date must be on or after start date") if end_date < start_date
    return failure("Season must be a valid year") if season.nil? || season <= 1800

    summary = { start_date: start_date.iso8601, end_date: end_date.iso8601, season: season, stages: [] }

    synchronize("schedules", summary) { MlbScheduleSync.call(start_date: start_date, end_date: end_date, game_types: GAME_TYPES, sport_id: 1) }
    synchronize("game details", summary) { MlbGameDetailsBatchSync.call(start_date: start_date, end_date: end_date) }
    synchronize("Statcast", summary) do
      PitchDataBatchSync.call(
        start_date: start_date,
        end_date: end_date,
        game_types: GAME_TYPES,
        chunk_days: NineLensConfig.fetch(:operations, :pitch_data, :default_chunk_days)
      )
    end
    synchronize_season_stats(summary)
    synchronize("40-man rosters", summary) do
      MlbRosterBatchSync.call(
        scope: "all",
        season: season,
        roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE,
        as_of: MlbRosterSyncBoundary.call(season: season)
      )
    end
    synchronize("missing player profiles", summary) { MlbPlayerProfilesSync.call(only_missing: true) }
    #synchronize("MLB transaction histories", summary) { MlbPlayerTeamHistoriesSync.call }
    synchronize("contextual benchmarks", summary) do
      ContextualBenchmarkRefresh.call(start_date: start_date, end_date: end_date)
    end

    success("Completed daily in-season refresh for #{start_date} through #{end_date}", summary)
  rescue StandardError => error
    failure(error.message, summary || {})
  end

  private

  attr_reader :start_date, :end_date, :season

  def synchronize_season_stats(summary)
    %w[batting pitching].each do |category|
      synchronize("#{category} season stats", summary) do
        download = PlayerStatsDownloader.call(category: category, start_year: season, end_year: season)
        raise download[:message] unless download[:success]

        PlayerStatsImporter.call(
          csv_data: download.dig(:data, :csv_data),
          source_name: "MLB #{category} season stats #{season}",
          replace_season: true
        )
      end
    end
  end

  def synchronize(name, summary)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    puts "→ Starting #{name}..."
    $stdout.flush

    result = yield
    raise "#{name} failed: #{result[:message]}" unless result[:success]

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    summary[:stages] << { name: name, success: true, message: result[:message], data: result[:data] }
    puts format("✓ Finished %<name>s in %<elapsed>.1fs: %<message>s", name: name, elapsed: elapsed, message: result[:message])
    $stdout.flush
  rescue StandardError => error
    puts "✗ #{name} failed: #{error.message}"
    $stdout.flush
    raise
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, data = {})
    { success: false, message: message, data: data.merge(errors: [ message ]) }
  end
end
