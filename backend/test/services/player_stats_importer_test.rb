require "test_helper"

class PlayerStatsImporterTest < ActiveSupport::TestCase
  test "imports valid rows, skips rows without stats, and collapses duplicate players" do
    csv_data = <<~CSV
      player_id,first_name,last_name,team_name,location_name,abbreviation,short_name,team_code,file_code,AVG,OPS
      24,Miguel,Cabrera,Tigers,Detroit,DET,Detroit,det,det,.320,.950
      17,Shohei,Ohtani,Dodgers,Los Angeles,LAD,Los Angeles,lan,la,.310,1.000
      27,Mike,Trout,Angels,Los Angeles,LAA,Angels,ana,ana,,
      24,Miguel,Cabrera,Tigers,Detroit,DET,Detroit,det,det,.321,.955
    CSV

    result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "spec/imports/players.csv"
    )

    assert result[:success]
    assert_equal 2, result.dig(:data, :imported_count)
    assert_equal 1, result.dig(:data, :skipped_count)
    assert_equal 1, result.dig(:data, :duplicate_count)
    assert_equal 2, result.dig(:data, :created_team_count)
    assert_equal 2, result.dig(:data, :created_player_count)

    assert_equal 2, Team.count
    assert_equal 2, Player.count
    assert_equal 2, PlayerStat.count

    tigers = Team.find_by!(team_code: "det")
    assert_equal "Detroit Tigers", tigers.name

    miguel_stats = PlayerStat.find_by!(player_id: "24")
    assert_equal 5, miguel_stats.row_number
    assert_equal ".321", miguel_stats.stats_data["AVG"]
    assert_equal ".955", miguel_stats.stats_data["OPS"]

    mike_error = result.dig(:data, :errors).find { |error| error[:row_number] == 4 }
    assert_equal "Missing statistical columns for player 27", mike_error[:error]
  end

  test "returns failure when required stat columns are missing from the csv header" do
    csv_data = <<~CSV
      player_id,first_name,last_name,team_name,location_name,abbreviation,short_name,team_code,file_code,AVG
      24,Miguel,Cabrera,Tigers,Detroit,DET,Detroit,det,det,.320
    CSV

    result = PlayerStatsImporter.call(
      csv_data: csv_data,
      source_name: "spec/imports/players.csv",
      required_stat_columns: %w[AVG OPS]
    )

    refute result[:success]
    assert_match "Missing required stat columns: OPS", result[:message]
    assert_equal 0, Team.count
    assert_equal 0, Player.count
    assert_equal 0, PlayerStat.count
  end

  test "returns failure for malformed csv input" do
    result = PlayerStatsImporter.call(
      csv_data: "player_id,first_name\n24,\"Miguel",
      source_name: "spec/imports/bad.csv"
    )

    refute result[:success]
    assert_match "Failed to parse CSV", result[:message]
    assert_equal 0, PlayerStat.count
  end
end
