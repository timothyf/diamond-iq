require "yaml"

class SampleDataBootstrap
  CONFIG_PATH = Rails.root.join("config/sample_data.yml").freeze

  def self.call(config: default_config, replace_existing: false, worker_count: nil, skip_season_stats: false, skip_profiles: false, skip_pitch_data: false, dry_run: false)
    new(
      config: config,
      replace_existing: replace_existing,
      worker_count: worker_count,
      skip_season_stats: skip_season_stats,
      skip_profiles: skip_profiles,
      skip_pitch_data: skip_pitch_data,
      dry_run: dry_run
    ).call
  end

  def self.default_config
    YAML.safe_load_file(CONFIG_PATH).deep_symbolize_keys
  end

  def initialize(config:, replace_existing:, worker_count:, skip_season_stats:, skip_profiles:, skip_pitch_data:, dry_run:)
    @config = config.deep_symbolize_keys
    @replace_existing = ActiveModel::Type::Boolean.new.cast(replace_existing)
    @worker_count = Integer(worker_count, exception: false) if worker_count.present?
    @skip_season_stats = ActiveModel::Type::Boolean.new.cast(skip_season_stats)
    @skip_profiles = ActiveModel::Type::Boolean.new.cast(skip_profiles)
    @skip_pitch_data = ActiveModel::Type::Boolean.new.cast(skip_pitch_data)
    @dry_run = ActiveModel::Type::Boolean.new.cast(dry_run)
  end

  def call
    return failure(validation_errors) if validation_errors.any?

    summary = { periods: periods.map { |period| period.transform_values(&:iso8601) }, stages: [] }
    return success("Sample-data bootstrap plan is valid", summary) if dry_run

    SeedFu.seed
    summary[:stages] << { name: "reference data", success: true }
    synchronize_season_stats!(summary) unless skip_season_stats
    periods.each { |period| synchronize_period!(period, summary) }
    synchronize_profiles!(summary) unless skip_profiles

    success("Bootstrapped sample data for #{periods.length} MLB periods", summary)
  rescue StandardError => error
    failure([ error.message ], summary || {})
  end

  private

  attr_reader :config, :replace_existing, :worker_count, :skip_season_stats, :skip_profiles, :skip_pitch_data, :dry_run

  def periods
    @periods ||= Array(config[:periods]).map do |period|
      { start_date: Date.iso8601(period.fetch(:start_date)), end_date: Date.iso8601(period.fetch(:end_date)) }
    end
  end

  def game_types
    config.fetch(:game_types, "R")
  end

  def pitch_chunk_days
    Integer(config.fetch(:pitch_chunk_days, 7))
  end

  def validation_errors
    return @validation_errors if defined?(@validation_errors)

    @validation_errors = []
    @validation_errors << "At least one sample period is required" if periods.empty?
    @validation_errors << "Pitch chunk days must be positive" unless pitch_chunk_days.positive?
    periods.each do |period|
      @validation_errors << "Sample period end date must be on or after its start date" if period[:end_date] < period[:start_date]
    end
    @validation_errors
  rescue KeyError, Date::Error, TypeError, ArgumentError => error
    @validation_errors = [ "Invalid sample-data configuration: #{error.message}" ]
  end

  def synchronize_season_stats!(summary)
    [ "batting", "pitching" ].each do |category|
      result = PlayerStatsDownloader.call(category: category, start_year: 2025, end_year: 2026)
      raise result[:message] unless result[:success]

      imported = PlayerStatsImporter.call(
        csv_data: result.dig(:data, :csv_data),
        source_name: "DiamondIQ sample #{category} season stats (2025-2026)",
        replace_season: replace_existing
      )
      raise imported[:message] unless imported[:success]

      summary[:stages] << { name: "#{category} season stats", success: true, imported_count: imported.dig(:data, :imported_count) }
    end
  end

  def synchronize_period!(period, summary)
    schedule = MlbScheduleSync.call(start_date: period[:start_date], end_date: period[:end_date], game_types: game_types, sport_id: 1)
    raise schedule[:message] unless schedule[:success]

    details = MlbGameDetailsBatchSync.call(start_date: period[:start_date], end_date: period[:end_date], worker_count: worker_count)
    raise details[:message] unless details[:success]

    pitch = unless skip_pitch_data
      result = PitchDataBatchSync.call(
        start_date: period[:start_date], end_date: period[:end_date], game_types: game_types,
        chunk_days: pitch_chunk_days, replace_existing: replace_existing
      )
      raise result[:message] unless result[:success]
      result
    end

    summary[:stages] << {
      name: "#{period[:start_date]} through #{period[:end_date]}", success: true,
      game_count: details.dig(:data, :game_count), pitch_rows: pitch&.dig(:data, :imported_count)
    }
  end

  def synchronize_profiles!(summary)
    result = MlbPlayerProfilesSync.call(only_missing: !replace_existing)
    raise result[:message] unless result[:success]

    summary[:stages] << { name: "player profiles", success: true, profile_count: result.dig(:data, :profile_count) }
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(errors, data = {})
    { success: false, message: errors.first, data: data.merge(errors: errors) }
  end
end
