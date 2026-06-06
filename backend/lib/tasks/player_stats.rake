namespace :player_stats do
  desc "Import player season stats from CSV. Usage: bin/rails 'player_stats:seed[path/to/file.csv]' REQUIRED_STAT_COLUMNS=gamesPlayed,ops"
  task :seed, [:file_path] => :environment do |_task, args|
    file_path = args[:file_path].presence || ENV["PLAYER_STATS_CSV"]

    if file_path.blank?
      abort "Usage: bin/rails 'player_stats:seed[path/to/file.csv]' or PLAYER_STATS_CSV=path bin/rails player_stats:seed"
    end

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
end
