# Keep `db:seed` aligned with SeedFu so one command loads app fixtures.
SeedFu.seed

player_stats_csv = ENV["PLAYER_STATS_CSV"].to_s.strip

if player_stats_csv.present?
  required_stat_columns = ENV.fetch("REQUIRED_STAT_COLUMNS", "")
    .split(",")
    .map(&:strip)
    .reject(&:blank?)

  result = PlayerStatsImporter.call(
    file_path: player_stats_csv,
    source_name: player_stats_csv,
    required_stat_columns: required_stat_columns
  )

  raise result[:message] unless result[:success]

  puts result[:message]
end
