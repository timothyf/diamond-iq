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

  it "imports pitching stats from verbose csv headers into abbreviated stat types" do
    create_stat_type(name: "W", label: "W", category: "pitching")
    create_stat_type(name: "L", label: "L", category: "pitching")
    create_stat_type(name: "GS", label: "GS", category: "pitching")
    create_stat_type(name: "CG", label: "CG", category: "pitching")
    create_stat_type(name: "ShO", label: "SHO", category: "pitching")
    create_stat_type(name: "SV", label: "SV", category: "pitching")
    create_stat_type(name: "SVO", label: "SVO", category: "pitching")
    create_stat_type(name: "ER", label: "ER", category: "pitching")

    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId,wins,losses,gamesStarted,completeGames,shutouts,saves,saveOpportunities,earnedRuns
      2026,2026,pitcher,694973,Jacob,Misiorowski,MIL,Milwaukee Brewers,Brewers,158,5,1,11,0,0,0,1,13
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/pitching_player_season_stats.csv")

    expect(result[:success]).to be(true)

    pitcher = Player.find_by!(mlb_id: 694973)
    expect(PlayerSeasonStat.find_by!(player: pitcher, stat_type: StatType.find_by!(name: "W", category: "pitching"), season: 2026).value).to eq(BigDecimal("5"))
    expect(PlayerSeasonStat.find_by!(player: pitcher, stat_type: StatType.find_by!(name: "L", category: "pitching"), season: 2026).value).to eq(BigDecimal("1"))
    expect(PlayerSeasonStat.find_by!(player: pitcher, stat_type: StatType.find_by!(name: "GS", category: "pitching"), season: 2026).value).to eq(BigDecimal("11"))
    expect(PlayerSeasonStat.find_by!(player: pitcher, stat_type: StatType.find_by!(name: "SVO", category: "pitching"), season: 2026).value).to eq(BigDecimal("1"))
    expect(PlayerSeasonStat.find_by!(player: pitcher, stat_type: StatType.find_by!(name: "ER", category: "pitching"), season: 2026).value).to eq(BigDecimal("13"))
  end

  it "prefers playerUseName over playerFirstName for display names" do
    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerName,playerFirstName,playerFullName,playerLastName,playerUseName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed,homeRuns,avg,ops
      2012,2012,batter,408234,Miguel Cabrera,Jose,Miguel Cabrera,Cabrera,Miguel,DET,Detroit Tigers,Tigers,116,161,44,.330,.999
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/player_use_name_player_season_stats.csv")

    expect(result[:success]).to be(true)

    miguel = Player.find_by!(mlb_id: 408234)
    expect(miguel.first_name).to eq("Miguel")
    expect(miguel.last_name).to eq("Cabrera")
  end

  it "replaces existing rows for imported season/category when replace_season is enabled" do
    create_stat_type(name: "W", label: "W", category: "pitching")

    team = Team.create!(
      mlb_id: 142,
      name: "Minnesota Twins",
      abbreviation: "MIN",
      team_name: "Twins",
      location_name: "Minnesota",
      short_name: "Twins",
      team_code: "142",
      file_code: "142"
    )

    old_player = Player.create!(mlb_id: 1, first_name: "Old", last_name: "Player", team: team)
    old_batting_type = StatType.find_by!(name: "homeRuns", category: "batting")
    old_pitching_type = StatType.find_by!(name: "W", category: "pitching")

    PlayerSeasonStat.create!(player: old_player, stat_type: old_batting_type, season: 2026, value: BigDecimal("30"))
    PlayerSeasonStat.create!(player: old_player, stat_type: old_pitching_type, season: 2026, value: BigDecimal("8"))

    csv_data = <<~CSV
      source_season,season,stat_type,playerId,playerFirstName,playerLastName,teamAbbrev,teamName,teamShortName,teamId,gamesPlayed,homeRuns,avg,ops
      2026,2026,batter,115636,Hal,Haydel,MIN,Minnesota Twins,Twins,142,4,1,.667,2.667
    CSV

    result = described_class.call(
      csv_data: csv_data,
      source_name: "spec/imports/replace_season_player_season_stats.csv",
      replace_season: true
    )

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :replace_season)).to be(true)
    expect(result.dig(:data, :replaced_rows_count)).to eq(1)

    expect(PlayerSeasonStat.where(player: old_player, stat_type: old_batting_type, season: 2026)).to be_empty
    expect(PlayerSeasonStat.where(player: old_player, stat_type: old_pitching_type, season: 2026).count).to eq(1)
  end

  it "keeps separate rows for team splits and a TOT row in the same season" do
    csv_data = <<~CSV
      source_season,season,fetched_at_utc,stat_type,playerId,playerFullName,teamAbbrev,teamName,teamShortName,gamesPlayed,homeRuns,avg,ops,playerFirstName,playerLastName,source_url,teamId,year
      2026,2026,2026-07-01T00:00:00+00:00,batter,123456,Alex Mason,DET,Detroit Tigers,Tigers,80,18,.295,.861,Alex,Mason,https://example.com/2026,116,2026
      2026,2026,2026-07-01T00:00:00+00:00,batter,123456,Alex Mason,LAD,Los Angeles Dodgers,Dodgers,70,12,.282,.834,Alex,Mason,https://example.com/2026,119,2026
      2026,2026,2026-07-01T00:00:00+00:00,batter,123456,Alex Mason,TOT,Total,Total,150,30,.289,.848,Alex,Mason,https://example.com/2026,0,2026
    CSV

    result = described_class.call(csv_data: csv_data, source_name: "spec/imports/player_season_stats_team_splits.csv")

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :duplicate_count)).to eq(0)

    player = Player.find_by!(mlb_id: 123456)
    home_runs = StatType.find_by!(name: "homeRuns", category: "batting")
    season_rows = PlayerSeasonStat.where(player: player, stat_type: home_runs, season: 2026)

    expect(season_rows.count).to eq(3)
    expect(season_rows.pluck(:scope_type, :scope_key)).to contain_exactly(
      ["team", "DET"],
      ["team", "LAD"],
      ["combined", "TOT"]
    )
    expect(season_rows.where(scope_type: "combined").pluck(:team_id)).to eq([nil])
  end
end
