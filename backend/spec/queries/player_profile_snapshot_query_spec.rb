require "rails_helper"

RSpec.describe PlayerProfileSnapshotQuery do
  it "displays the team a retired player spent the most seasons with" do
    longest_team = create_team(attributes: { name: "Detroit Tigers" })
    recent_team = create_team(attributes: { name: "Miami Marlins" })
    player = create_player(team: recent_team)
    player.create_profile!(
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "active" => false }
    )
    stat_type = create_stat_type(name: "gamesPlayed", label: "G", category: "batting")
    [ 2018, 2019, 2020 ].each do |season|
      create_player_season_stat(player: player, stat_type: stat_type, attributes: { team: longest_team, season: season, value: 100 })
    end
    [ 2021, 2022 ].each do |season|
      create_player_season_stat(player: player, stat_type: stat_type, attributes: { team: recent_team, season: season, value: 100 })
    end

    display_team = described_class.new(player: player).result.fetch(:display_team)

    expect(display_team).to include(id: longest_team.id, name: "Detroit Tigers")
  end

  it "keeps an active player's current membership team in the header" do
    cached_team = create_team
    current_team = create_team
    player = create_player(team: cached_team)
    player.create_profile!(
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "active" => true }
    )
    create_team_membership(player: player, team: current_team, starts_on: Date.current - 1.month)

    display_team = described_class.new(player: player).result.fetch(:display_team)

    expect(display_team).to include(id: current_team.id)
  end

  it "coalesces adjacent same-team roster windows into one organization tenure" do
    player = create_player
    team = player.team
    first = create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2024, 12, 31),
      ends_on: Date.new(2025, 12, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2025, 12, 31),
      ends_on: Date.new(2026, 7, 13),
      roster_status: "active"
    )
    latest = create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2026, 7, 14),
      roster_status: "active",
      source_status_description: "Active"
    )

    history = described_class.new(player: player, on: Date.new(2026, 7, 17)).result.fetch(:team_history)

    expect(history).to contain_exactly(
      hash_including(
        id: latest.id,
        starts_on: first.starts_on,
        ends_on: nil,
        current: true,
        roster_status: "active",
        source_status_description: "Active",
        team: hash_including(id: team.id)
      )
    )
  end

  it "keeps separate tenures when a player leaves and later returns to a team" do
    player = create_player
    original_team = player.team
    other_team = create_team
    create_team_membership(player: player, team: original_team, starts_on: Date.new(2024, 1, 1), ends_on: Date.new(2024, 6, 30))
    create_team_membership(player: player, team: other_team, starts_on: Date.new(2024, 7, 1), ends_on: Date.new(2024, 12, 31))
    create_team_membership(player: player, team: original_team, starts_on: Date.new(2025, 1, 1))

    history = described_class.new(player: player, on: Date.new(2025, 6, 1)).result.fetch(:team_history)

    expect(history.map { |tenure| tenure.dig(:team, :id) }).to eq([ original_team.id, other_team.id, original_team.id ])
    expect(history.first).to include(current: true, roster_status: "active")
    expect(history.drop(1)).to all(
      include(current: false, roster_status: "organization", source_status_description: "Organization tenure")
    )
  end

  it "does not let a stale roster snapshot extend a transaction-derived tenure" do
    former_team = create_team
    current_team = create_team
    player = create_player(team: current_team)
    create_team_membership(
      player: player,
      team: former_team,
      starts_on: Date.new(2022, 8, 7),
      ends_on: Date.new(2025, 7, 30),
      roster_status: "organization",
      source_name: "MLB Stats API transactions"
    )
    create_team_membership(
      player: player,
      team: former_team,
      starts_on: Date.new(2024, 12, 31),
      ends_on: Date.new(2025, 12, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: player,
      team: current_team,
      starts_on: Date.new(2025, 7, 31),
      roster_status: "organization",
      source_name: "MLB Stats API transactions"
    )

    history = described_class.new(player: player, on: Date.new(2026, 7, 17)).result.fetch(:team_history)
    former_tenure = history.find { |tenure| tenure.dig(:team, :id) == former_team.id }

    expect(former_tenure).to include(
      starts_on: Date.new(2022, 8, 7),
      ends_on: Date.new(2025, 7, 30),
      current: false,
      source_status_description: "Organization tenure"
    )
  end

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
      walks: create_stat_type(name: "baseOnBalls", label: "BB", category: "batting"),
      hitByPitch: create_stat_type(name: "hitByPitch", label: "HBP", category: "batting"),
      sacFlies: create_stat_type(name: "sacFlies", label: "SF", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      obp: create_stat_type(name: "obp", label: "OBP", category: "batting"),
      slg: create_stat_type(name: "slg", label: "SLG", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting")
    }
    season_values = {
      2025 => { gamesPlayed: 120, atBats: 400, hits: 100, doubles: 20, triples: 2, homeRuns: 10, walks: 40, hitByPitch: 5, sacFlies: 4, avg: 0.250, obp: 0.323, slg: 0.385, ops: 0.708 },
      2026 => { gamesPlayed: 60, atBats: 200, hits: 60, doubles: 10, triples: 1, homeRuns: 20, walks: 20, hitByPitch: 2, sacFlies: 2, avg: 0.300, obp: 0.366, slg: 0.660, ops: 1.026 }
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
    seasons = career.fetch(:seasons).index_by { |row| row.fetch(:season) }

    expect(career).to include(
      category: "batting",
      first_season: 2025,
      last_season: 2026,
      season_count: 2
    )
    expect(stats.fetch("gamesPlayed").fetch(:value)).to eq("180")
    expect(stats.fetch("homeRuns").fetch(:value)).to eq("30")
    expect(stats.fetch("avg").fetch(:value)).to eq("0.267")
    expect(stats.fetch("obp").fetch(:value)).to eq("0.337")
    expect(stats.fetch("slg").fetch(:value)).to eq("0.477")
    expect(stats.fetch("ops").fetch(:value)).to eq("0.814")
    expect(career.fetch(:columns).map { |column| column.fetch(:key) }).to include("gamesPlayed", "homeRuns", "avg", "slg")
    expect(seasons.fetch(2025).fetch(:stats)).to include(
      hash_including(key: "gamesPlayed", value: "120"),
      hash_including(key: "homeRuns", value: "10"),
      hash_including(key: "avg", value: "0.250"),
      hash_including(key: "obp", value: "0.323"),
      hash_including(key: "ops", value: "0.708")
    )
    expect(seasons.fetch(2026).fetch(:stats)).to include(
      hash_including(key: "gamesPlayed", value: "60"),
      hash_including(key: "homeRuns", value: "20"),
      hash_including(key: "avg", value: "0.300"),
      hash_including(key: "obp", value: "0.366"),
      hash_including(key: "ops", value: "1.026")
    )
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
      whip: create_stat_type(name: "whip", label: "WHIP", category: "pitching"),
      atBats: create_stat_type(name: "atBats", label: "AB", category: "pitching"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "pitching")
    }
    season_values = {
      2025 => { inningsPitched: 10.2, earnedRuns: 3, hits: 8, walks: 2, era: 2.53, whip: 0.94, atBats: 40, avg: 0.200 },
      2026 => { inningsPitched: 5.1, earnedRuns: 2, hits: 4, walks: 1, era: 3.38, whip: 0.94, atBats: 40, avg: 0.100 }
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
    seasons = career.fetch(:seasons).index_by { |row| row.fetch(:season) }

    expect(career).to include(category: "pitching", season_count: 2)
    expect(stats.fetch("inningsPitched").fetch(:value)).to eq("16.0")
    expect(stats.fetch("ERA").fetch(:value)).to eq("2.81")
    expect(stats.fetch("whip").fetch(:value)).to eq("0.94")
    expect(stats.fetch("avg").fetch(:value)).to eq("0.150")
    expect(seasons.fetch(2025).fetch(:stats)).to include(hash_including(key: "inningsPitched", value: "10.2"))
    expect(seasons.fetch(2026).fetch(:stats)).to include(hash_including(key: "inningsPitched", value: "5.1"))
  end
end
