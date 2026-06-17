namespace :player_stats do
  def resolve_import_paths(explicit_path = nil)
    path = explicit_path.presence || ENV["PLAYER_STATS_CSV"].presence
    return csv_paths_from(path) if path.present?

    preferred_directory_paths = PlayerStatsCsvLocator.all(search_roots: [PlayerStatsCsvLocator.preferred_output_directory])
    return preferred_directory_paths if preferred_directory_paths.any?

    located_path = PlayerStatsCsvLocator.call
    located_path.present? ? [located_path] : []
  end

  def csv_paths_from(path)
    pathname = Pathname(path)

    if pathname.directory?
      PlayerStatsCsvLocator.all(search_roots: [pathname])
    elsif pathname.file?
      [pathname.to_s]
    else
      []
    end
  end

  def import_player_stats_from!(file_path)
    required_stat_columns = ENV.fetch("REQUIRED_STAT_COLUMNS", "")
      .split(",")
      .map(&:strip)
      .reject(&:blank?)

    result = PlayerStatsImporter.call(
      file_path: file_path,
      source_name: file_path,
      required_stat_columns: required_stat_columns
    )

    puts result[:message]

    if result[:success]
      data = result[:data] || {}
      puts "Imported season stat records: #{data[:imported_count]}"
      puts "Created teams: #{data[:created_team_count]}"
      puts "Created players: #{data[:created_player_count]}"
      puts "Skipped rows: #{data[:skipped_count]}"
      puts "Duplicate rows collapsed: #{data[:duplicate_count]}"

      Array(data[:errors]).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end
    else
      Array(result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Player season stats import failed"
    end
  end

  desc "Import player season stats from CSV. Usage: bin/rails 'player_stats:seed[path/to/file.csv]' REQUIRED_STAT_COLUMNS=gamesPlayed,ops"
  task :seed, [:file_path] => :environment do |_task, args|
    file_path = args[:file_path].presence || ENV["PLAYER_STATS_CSV"]

    if file_path.blank?
      abort "Usage: bin/rails 'player_stats:seed[path/to/file.csv]' or PLAYER_STATS_CSV=path bin/rails player_stats:seed"
    end

    import_player_stats_from!(file_path)
  end

  desc "Download MLB player season stats and import them. Usage: bin/rails 'player_stats:download[batting,2025,2026]' REPLACE_SEASON=1"
  task :download, [:category, :start_year, :end_year] => :environment do |_task, args|
    category = args[:category].presence || ENV["CATEGORY"].presence || "batting"
    start_year = args[:start_year].presence || ENV["START_YEAR"].presence
    end_year = args[:end_year].presence || ENV["END_YEAR"].presence || start_year

    if start_year.blank?
      abort "Usage: bin/rails 'player_stats:download[batting,2025,2026]' or START_YEAR=2025 CATEGORY=pitching bin/rails player_stats:download"
    end

    puts "Downloading #{category} stats from MLB for #{start_year}-#{end_year}..."
    download_result = PlayerStatsDownloader.call(category: category, start_year: start_year, end_year: end_year)

    unless download_result[:success]
      abort download_result[:message]
    end

    puts download_result[:message]
    import_result = PlayerStatsImporter.call(
      csv_data: download_result.dig(:data, :csv_data),
      source_name: "MLB #{download_result.dig(:data, :category)} #{download_result.dig(:data, :seasons).join('-')}",
      replace_season: %w[1 true t yes y on].include?(ENV["REPLACE_SEASON"].to_s.strip.downcase)
    )

    puts import_result[:message]

    unless import_result[:success]
      Array(import_result.dig(:data, :errors)).each do |error|
        puts "Row #{error[:row_number]}: #{error[:error]}"
      end

      abort "Player season stats download import failed"
    end

    data = import_result[:data] || {}
    puts "Downloaded MLB rows: #{download_result.dig(:data, :row_count)}"
    puts "Imported season stat records: #{data[:imported_count]}"
    puts "Created teams: #{data[:created_team_count]}"
    puts "Created players: #{data[:created_player_count]}"
    puts "Skipped rows: #{data[:skipped_count]}"
    puts "Duplicate rows collapsed: #{data[:duplicate_count]}"
    puts "Replaced rows: #{data[:replaced_rows_count]}" if data[:replace_season]
  end

  desc "Seed stat_types and reimport player season stats from the preferred local CSV source. Usage: bin/rails player_stats:reimport or PLAYER_STATS_CSV=/path/file.csv bin/rails player_stats:reimport"
  task :reimport, [:file_path] => :environment do |_task, args|
    file_paths = resolve_import_paths(args[:file_path])

    if file_paths.blank?
      abort <<~MESSAGE
        Unable to find a player season stats CSV automatically.
        Try:
          PLAYER_STATS_CSV=/absolute/path/to/file.csv bin/rails player_stats:reimport
      MESSAGE
    end

    puts "Seeding stat types..."
    SeedFu.seed
    puts "Using CSV source#{'s' if file_paths.many?}:"
    file_paths.each { |file_path| puts "- #{file_path}" }

    file_paths.each do |file_path|
      import_player_stats_from!(file_path)
    end
  end
end
