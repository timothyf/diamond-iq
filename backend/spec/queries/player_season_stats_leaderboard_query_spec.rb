require "rails_helper"

RSpec.describe PlayerSeasonStatsLeaderboardQuery, type: :model do
  it "returns player leaderboard rows with batting stats across columns" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    miguel = create_player(team: tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    shohei = create_player(team: dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })
    [
      ["gamesPlayed", "G"],
      ["atBats", "AB"],
      ["runs", "R"],
      ["hits", "H"],
      ["doubles", "2B"],
      ["triples", "3B"],
      ["homeRuns", "HR"],
      ["rbi", "RBI"],
      ["baseOnBalls", "BB"],
      ["strikeOuts", "SO"],
      ["stolenBases", "SB"],
      ["caughtStealing", "CS"],
      ["avg", "AVG"],
      ["obp", "OBP"],
      ["slg", "SLG"],
      ["ops", "OPS"]
    ].each do |name, label|
      create_stat_type(name: name, label: label, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "102",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: miguel,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "118",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    query = described_class.new(
      params: {
        page: 1,
        per_page: 5,
        sort: "-homeRuns",
        filter: { category: "batting", season: 2024 }
      }
    )

    expect(query.results.map { |row| row.dig(:player, :full_name) }).to eq(["Shohei Ohtani", "Miguel Cabrera"])
    expect(query.results.first[:rank]).to eq(1)
    expect(query.results.first.dig(:stats, "homeRuns")).to eq("41.0")
    expect(query.results.first.dig(:stats, "ops")).to eq("1.013")
    expect(query.metadata[:total_count]).to eq(2)
    expect(query.metadata[:sort]).to eq("-homeRuns")
    expect(query.metadata[:category]).to eq("batting")
    expect(query.metadata[:available_seasons]).to eq([2024])
    expect(query.metadata[:available_teams]).to eq(
      [
        {
          id: tigers.id,
          mlb_id: 116,
          abbreviation: "DET",
          name: "Detroit Tigers",
          team_name: "Tigers",
          location_name: "Detroit",
          short_name: "Detroit"
        },
        {
          id: dodgers.id,
          mlb_id: 119,
          abbreviation: "LAD",
          name: "Los Angeles Dodgers",
          team_name: "Dodgers",
          location_name: "Los Angeles",
          short_name: "Los Angeles"
        }
      ]
    )
    expect(query.metadata[:columns].map { |column| column[:label] }).to include("HR", "OPS")
  end

  it "sorts batting leaderboard rows by strikeOuts numerically" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    miguel = create_player(team: tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    shohei = create_player(team: dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })

    %w[gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts stolenBases caughtStealing avg obp slg ops].each do |name|
      create_stat_type(name: name, label: name, category: "batting") unless StatType.exists?(name: name, category: "batting")
    end

    {
      "gamesPlayed" => "150",
      "atBats" => "540",
      "runs" => "88",
      "hits" => "162",
      "doubles" => "30",
      "triples" => "2",
      "homeRuns" => "24",
      "rbi" => "91",
      "baseOnBalls" => "60",
      "strikeOuts" => "12",
      "stolenBases" => "4",
      "caughtStealing" => "1",
      "avg" => ".300",
      "obp" => ".372",
      "slg" => ".515",
      "ops" => ".887"
    }.each do |name, value|
      create_player_season_stat(
        player: miguel,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    {
      "gamesPlayed" => "155",
      "atBats" => "560",
      "runs" => "102",
      "hits" => "171",
      "doubles" => "28",
      "triples" => "4",
      "homeRuns" => "41",
      "rbi" => "99",
      "baseOnBalls" => "88",
      "strikeOuts" => "2",
      "stolenBases" => "18",
      "caughtStealing" => "3",
      "avg" => ".305",
      "obp" => ".401",
      "slg" => ".612",
      "ops" => "1.013"
    }.each do |name, value|
      create_player_season_stat(
        player: shohei,
        stat_type: StatType.find_by!(name: name, category: "batting"),
        attributes: { season: 2024, value: value }
      )
    end

    query = described_class.new(
      params: {
        view: "leaderboard",
        sort: "-strikeOuts",
        filter: { category: "batting", season: 2024 }
      }
    )

    expect(query.results.map { |row| [row.dig(:player, :full_name), row.dig(:stats, "strikeOuts")] }).to eq([
      ["Miguel Cabrera", "12.0"],
      ["Shohei Ohtani", "2.0"]
    ])
  end

  it "uses the MLB-style pitching column order and labels" do
    query = described_class.new(
      params: {
        filter: { category: "pitching" }
      }
    )

    expect(query.metadata[:columns].map { |column| [column[:key], column[:label]] }).to eq(
      [
        ["W", "W"],
        ["L", "L"],
        ["ERA", "ERA"],
        ["G", "G"],
        ["GS", "GS"],
        ["CG", "CG"],
        ["ShO", "SHO"],
        ["SV", "SV"],
        ["SVO", "SVO"],
        ["inningsPitched", "IP"],
        ["hits", "H"],
        ["runs", "R"],
        ["ER", "ER"],
        ["homeRuns", "HR"],
        ["hitByPitch", "HB"],
        ["baseOnBalls", "BB"],
        ["strikeOuts", "SO"],
        ["whip", "WHIP"],
        ["avg", "AVG"]
      ]
    )
  end

  it "fills pitching leaderboard stats from alias fields and derives earned runs when needed" do
    brewers = create_team(
      mlb_id: 158,
      name: "Milwaukee Brewers",
      abbreviation: "MIL",
      team_name: "Brewers",
      location_name: "Milwaukee",
      short_name: "Brewers",
      team_code: "mil",
      file_code: "mil"
    )
    jacob = create_player(team: brewers, attributes: { mlb_id: 694973, first_name: "Jacob", last_name: "Misiorowski" })

    [
      ["ERA", "ERA"],
      ["gamesPitched", "GP"],
      ["inningsPitched", "IP"],
      ["hits", "H"],
      ["runs", "R"],
      ["homeRuns", "HR"],
      ["hitByPitch", "HBP"],
      ["baseOnBalls", "BB"],
      ["strikeOuts", "SO"],
      ["whip", "WHIP"],
      ["avg", "AVG"]
    ].each do |name, label|
      create_stat_type(name: name, label: label, category: "pitching")
    end

    {
      "ERA" => "1.83",
      "gamesPitched" => "12",
      "inningsPitched" => "64.0",
      "hits" => "34",
      "runs" => "15",
      "homeRuns" => "4",
      "hitByPitch" => "5",
      "baseOnBalls" => "19",
      "strikeOuts" => "100",
      "whip" => "0.83",
      "avg" => "0.153"
    }.each do |name, value|
      create_player_season_stat(
        player: jacob,
        stat_type: StatType.find_by!(name: name, category: "pitching"),
        attributes: { season: 2026, value: value }
      )
    end

    query = described_class.new(
      params: {
        filter: { category: "pitching", season: 2026 }
      }
    )

    row = query.results.first

    expect(row.dig(:stats, "G")).to eq("12.0")
    expect(row.dig(:stats, "ER")).to eq("13.0")
    expect(row.dig(:stats, "homeRuns")).to eq("4.0")
    expect(row.dig(:stats, "hitByPitch")).to eq("5.0")
    expect(row.dig(:stats, "baseOnBalls")).to eq("19.0")
    expect(row.dig(:stats, "strikeOuts")).to eq("100.0")
    expect(query.metadata[:columns].map { |column| column[:key] }).to eq(
      %w[ERA G inningsPitched hits runs ER homeRuns hitByPitch baseOnBalls strikeOuts whip avg]
    )
  end
end
