require "rails_helper"

RSpec.describe PlayerStatsImporter, type: :service do
  before do
    create_stat_type(name: "gamesPlayed", label: "G", category: "batting")
    create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_stat_type(name: "avg", label: "AVG", category: "batting")
    create_stat_type(name: "ops", label: "OPS", category: "batting")
  end

  it "imports player season stats from the csv shape and collapses duplicate rows" do
    csv_data = <<~CSV
      source_season,season,fetched_at_utc,stat_type,playerId,playerFullName,teamAbbrev,teamName,teamShortName,gamesPlayed,homeRuns,avg,ops,playerFirstName,playerLastName,source_url,teamId,year
      1970,1970,2026-05-28T23:19:08+00:00,batter,115636,Hal Haydel,MIN,Minnesota Twins,Twins,4,1,.667,2.667,Hal,Haydel,https://example.com/1970,142,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,110812,Bo Belinsky,CIN,Cincinnati Reds,Reds,3,0,1.000,2.000,Bo,Belinsky,https://example.com/1970,113,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,115636,Hal Haydel,MIN,Minnesota Twins,Twins,5,2,.700,2.800,Hal,Haydel,https://example.com/1970,142,1970
      1970,1970,2026-05-28T23:19:08+00:00,batter,116437,Mike Jackson,PHI,Philadelphia Phillies,Phillies,5,0,.---,.---,Mike,Jackson,https://example.com/1970,143,1970
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/player_season_stats.csv")

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :imported_count)).to eq(10)
    expect(result.dig(:data, :skipped_count)).to eq(0)
    expect(result.dig(:data, :duplicate_count)).to eq(1)
    expect(result.dig(:data, :created_team_count)).to eq(3)
    expect(result.dig(:data, :created_player_count)).to eq(3)
    expect(Team.count).to eq(3)
    expect(Player.count).to eq(3)
    expect(PlayerSeasonStat.count).to eq(10)

    twins = Team.find_by!(abbreviation: "MIN")
    hal = Player.find_by!(mlb_id: 115636)
    home_runs = StatType.find_by!(name: "homeRuns", category: "batting")
    ops = StatType.find_by!(name: "ops", category: "batting")

    expect(twins.mlb_id).to eq(142)
    expect(twins.location_name).to eq("Minnesota")
    expect(hal.first_name).to eq("Hal")
    expect(hal.last_name).to eq("Haydel")
    expect(PlayerSeasonStat.find_by!(player: hal, stat_type: home_runs, season: 1970).value).to eq(BigDecimal("2"))
    expect(PlayerSeasonStat.find_by!(player: hal, stat_type: ops, season: 1970).value).to eq(BigDecimal("2.8"))

    mike = Player.find_by!(mlb_id: 116437)
    games_played = StatType.find_by!(name: "gamesPlayed", category: "batting")

    expect(mike.first_name).to eq("Mike")
    expect(mike.last_name).to eq("Jackson")
    expect(PlayerSeasonStat.find_by!(player: mike, stat_type: games_played, season: 1970).value).to eq(BigDecimal("5"))
    expect(PlayerSeasonStat.find_by!(player: mike, stat_type: home_runs, season: 1970).value).to eq(BigDecimal("0"))
    expect(result.dig(:data, :errors)).to eq([])
  end

  it "returns failure when required stat columns are missing" do
    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed,avg
      1970,1970,batter,115636,Hal,Haydel,MIN,Minnesota Twins,Twins,142,4,.667
    CSV

    result = described_class.call(
      csv_data: csv_data,
      source_name: "spec/imports/player_season_stats.csv",
      required_stat_columns: %w[gamesPlayed ops]
    )

    expect(result[:success]).to be(false)
    expect(result[:message]).to include("Missing required stat columns: ops")
    expect(Team.count).to eq(0)
    expect(Player.count).to eq(0)
    expect(PlayerSeasonStat.count).to eq(0)
  end

  it "returns failure for malformed csv input" do
    result = described_class.call(
      csv_data: "season,stat_type,playerId\n1970,batter,\"115636",
      source_name: "spec/imports/bad.csv"
    )

    expect(result[:success]).to be(false)
    expect(result[:message]).to include("Failed to parse CSV")
    expect(PlayerSeasonStat.count).to eq(0)
  end
end
