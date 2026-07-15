require "rails_helper"

RSpec.describe PlayerProfileSnapshotQuery do
  it "prefers a pitching overview for a player whose primary position is pitcher" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    era = create_stat_type(name: "ERA", label: "ERA", category: "pitching")
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_player_season_stat(player: player, stat_type: era, attributes: { season: 2026, value: 2.85 })
    create_player_season_stat(player: player, stat_type: home_runs, attributes: { season: 2026, value: 1 })

    overview = described_class.new(player: player).result.fetch(:season_overview)

    expect(overview).to include(season: 2026, category: "pitching", preferred_category: "pitching")
    expect(overview.fetch(:stats)).to include(hash_including(key: "ERA", value: "2.85"))
    expect(overview.fetch(:stats)).not_to include(hash_including(key: "homeRuns"))
  end

  it "returns a stable empty overview when season statistics are unavailable" do
    player = create_player

    expect(described_class.new(player: player).result.fetch(:season_overview)).to eq(
      season: nil,
      category: "batting",
      preferred_category: "batting",
      stats: []
    )
  end

  it "totals counting stats and recalculates batting rates across stored seasons" do
    player = create_player
    definitions = {
      gamesPlayed: create_stat_type(name: "gamesPlayed", label: "G", category: "batting"),
      atBats: create_stat_type(name: "atBats", label: "AB", category: "batting"),
      hits: create_stat_type(name: "hits", label: "H", category: "batting"),
      doubles: create_stat_type(name: "doubles", label: "2B", category: "batting"),
      triples: create_stat_type(name: "triples", label: "3B", category: "batting"),
      homeRuns: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      slg: create_stat_type(name: "slg", label: "SLG", category: "batting")
    }
    season_values = {
      2025 => { gamesPlayed: 120, atBats: 400, hits: 100, doubles: 20, triples: 2, homeRuns: 10, avg: 0.250, slg: 0.385 },
      2026 => { gamesPlayed: 60, atBats: 200, hits: 60, doubles: 10, triples: 1, homeRuns: 20, avg: 0.300, slg: 0.660 }
    }

    season_values.each do |season, values|
      values.each do |key, value|
        create_player_season_stat(
          player: player,
          stat_type: definitions.fetch(key),
          attributes: { season: season, value: value }
        )
      end
    end

    career = described_class.new(player: player).result.fetch(:career_overview)
    stats = career.fetch(:stats).index_by { |stat| stat.fetch(:key) }

    expect(career).to include(
      category: "batting",
      first_season: 2025,
      last_season: 2026,
      season_count: 2
    )
    expect(stats.fetch("gamesPlayed").fetch(:value)).to eq("180")
    expect(stats.fetch("homeRuns").fetch(:value)).to eq("30")
    expect(stats.fetch("avg").fetch(:value)).to eq("0.267")
    expect(stats.fetch("slg").fetch(:value)).to eq("0.477")
  end

  it "combines baseball innings and recalculates career pitching rates" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    definitions = {
      inningsPitched: create_stat_type(name: "inningsPitched", label: "IP", category: "pitching"),
      earnedRuns: create_stat_type(name: "ER", label: "ER", category: "pitching"),
      hits: create_stat_type(name: "hits", label: "H", category: "pitching"),
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "pitching"),
      era: create_stat_type(name: "ERA", label: "ERA", category: "pitching"),
      whip: create_stat_type(name: "whip", label: "WHIP", category: "pitching")
    }
    season_values = {
      2025 => { inningsPitched: 10.2, earnedRuns: 3, hits: 8, walks: 2, era: 2.53, whip: 0.94 },
      2026 => { inningsPitched: 5.1, earnedRuns: 2, hits: 4, walks: 1, era: 3.38, whip: 0.94 }
    }

    season_values.each do |season, values|
      values.each do |key, value|
        create_player_season_stat(
          player: player,
          stat_type: definitions.fetch(key),
          attributes: { season: season, value: value }
        )
      end
    end

    career = described_class.new(player: player).result.fetch(:career_overview)
    stats = career.fetch(:stats).index_by { |stat| stat.fetch(:key) }

    expect(career).to include(category: "pitching", season_count: 2)
    expect(stats.fetch("inningsPitched").fetch(:value)).to eq("16.0")
    expect(stats.fetch("ERA").fetch(:value)).to eq("2.81")
    expect(stats.fetch("whip").fetch(:value)).to eq("0.938")
  end
end
