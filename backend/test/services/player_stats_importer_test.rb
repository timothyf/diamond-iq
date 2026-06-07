require "test_helper"

class PlayerStatsImporterTest < ActiveSupport::TestCase
  setup do
    @games_played = StatType.create!(name: "gamesPlayed", label: "G", category: "batting")
    @home_runs = StatType.create!(name: "homeRuns", label: "HR", category: "batting")
    @avg = StatType.create!(name: "avg", label: "AVG", category: "batting")
    @ops = StatType.create!(name: "ops", label: "OPS", category: "batting")
  end

  test "imports player season stats from the real csv shape and collapses duplicate rows" do
    csv_data = <<~CSV
      source_season,season,fetched_at_utc,stat_type,playerId,playerFullName,teamAbbrev,teamName,teamShortName,gamesPlayed,homeRuns,avg,ops,playerFirstName,playerLastName,source_url,year
      1970,1970,2026-05-28T23:19:08+00:00,batter,115636,Hal Haydel,MIN,Minnesota Twins,Twins,4,1,.667,2.667,Hal,Haydel,https://example.com/1970,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,110812,Bo Belinsky,CIN,Cincinnati Reds,Reds,3,0,1.000,2.000,Bo,Belinsky,https://example.com/1970,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,115636,Hal Haydel,MIN,Minnesota Twins,Twins,5,2,.700,2.800,Hal,Haydel,https://example.com/1970,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,116437,Mike Jackson,PHI,Philadelphia Phillies,Phillies,5,0,.---,.---,Mike,Jackson,https://example.com/1970,1970
    CSV

    result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "spec/imports/player_season_stats.csv"
    )

    assert result[:success]
    assert_equal 8, result.dig(:data, :imported_count)
    assert_equal 1, result.dig(:data, :skipped_count)
    assert_equal 1, result.dig(:data, :duplicate_count)
    assert_equal 2, result.dig(:data, :created_team_count)
    assert_equal 2, result.dig(:data, :created_player_count)

    assert_equal 2, Team.count
    assert_equal 2, Player.count
    assert_equal 8, PlayerSeasonStat.count

    twins = Team.find_by!(abbreviation: "MIN")
    assert_equal 142, twins.mlb_id
    assert_equal "Minnesota Twins", twins.name
    assert_equal "Twins", twins.team_name
    assert_equal "Minnesota", twins.location_name

    hal = Player.find_by!(mlb_id: 115636)
    assert_equal "Hal", hal.first_name
    assert_equal "Haydel", hal.last_name
    hal_home_runs = PlayerSeasonStat.find_by!(player: hal, stat_type: @home_runs, season: 1970)
    hal_ops = PlayerSeasonStat.find_by!(player: hal, stat_type: @ops, season: 1970)

    assert_equal BigDecimal("2"), hal_home_runs.value
    assert_equal BigDecimal("2.8"), hal_ops.value

    skipped_error = result.dig(:data, :errors).find { |error| error[:row_number] == 5 }
    assert_equal "No importable batting stats found for player 116437", skipped_error[:error]
  end

  test "returns failure when required stat columns are missing from the csv header" do
    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,gamesPlayed,avg
      1970,1970,batter,115636,Hal,Haydel,MIN,Minnesota Twins,Twins,4,.667
    CSV

    result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "spec/imports/player_season_stats.csv",
      required_stat_columns: %w[gamesPlayed ops]
    )

    refute result[:success]
    assert_match "Missing required stat columns: ops", result[:message]
    assert_equal 0, Team.count
    assert_equal 0, Player.count
    assert_equal 0, PlayerSeasonStat.count
  end

  test "returns failure for malformed csv input" do
    result = PlayerStatsImporter.call(
      csv_data: "season,stat_type,playerId\n1970,batter,\"115636",
      source_name: "spec/imports/bad.csv"
    )

    refute result[:success]
    assert_match "Failed to parse CSV", result[:message]
    assert_equal 0, PlayerSeasonStat.count
  end

  test "prefers playerUseName over playerFirstName for display names" do
    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerName,playerFirstName,playerFullName,playerLastName,playerUseName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed,homeRuns,avg,ops
      2012,2012,batter,408234,Miguel Cabrera,Jose,Miguel Cabrera,Cabrera,Miguel,DET,Detroit Tigers,Tigers,116,161,44,.330,.999
    CSV

    result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "spec/imports/player_use_name_player_season_stats.csv"
    )

    assert result[:success]

    miguel = Player.find_by!(mlb_id: 408234)
    assert_equal "Miguel", miguel.first_name
    assert_equal "Cabrera", miguel.last_name
  end
end
