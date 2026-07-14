require "rails_helper"

RSpec.describe PlayerSeasonStatsIndexQuery, type: :model do
  describe "#results" do
    it "filters by player name, category, and value range" do
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
      war = create_stat_type(name: "war", label: "WAR", category: "batting")
      ops = create_stat_type(name: "ops", label: "OPS", category: "batting")
      era = create_stat_type(name: "era", label: "ERA", category: "pitching")

      create_player_season_stat(player: miguel, stat_type: war, attributes: { season: 2024, value: 3.2 })
      create_player_season_stat(player: miguel, stat_type: ops, attributes: { season: 2025, value: 0.95 })
      create_player_season_stat(player: shohei, stat_type: era, attributes: { season: 2024, value: 2.35 })

      query = described_class.new(
        params: { filter: { player_name: "mig", category: "batting", min_value: "1.0", max_value: "4.0" }, sort: "-value" }
      )

      expect(query.results.map(&:value)).to eq([BigDecimal("3.2")])
      expect(query.metadata[:filters]).to eq(
        player_name: "mig",
        category: "batting",
        min_value: BigDecimal("1.0"),
        max_value: BigDecimal("4.0")
      )
    end

    it "normalizes invalid pagination and sort values" do
      player = create_player
      stat_type = create_stat_type

      create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 2025, value: 2.5 })
      create_player_season_stat(player: player, stat_type: create_stat_type(name: "ops", label: "OPS"), attributes: { season: 2024, value: 1.5 })

      query = described_class.new(params: { page: 0, per_page: 500, sort: "not_a_field" })

      expect(query.results.map(&:season)).to eq([2024, 2025])
      expect(query.metadata[:page]).to eq(1)
      expect(query.metadata[:per_page]).to eq(100)
      expect(query.metadata[:sort]).to eq("season")
    end

    it "filters by historical season team id instead of player's current team" do
      current_team = create_team(
        mlb_id: 136,
        name: "Seattle Mariners",
        abbreviation: "SEA",
        team_name: "Mariners",
        location_name: "Seattle",
        short_name: "Seattle",
        team_code: "sea",
        file_code: "sea"
      )
      historical_team = create_team(
        mlb_id: 116,
        name: "Detroit Tigers",
        abbreviation: "DET",
        team_name: "Tigers",
        location_name: "Detroit",
        short_name: "Detroit",
        team_code: "det",
        file_code: "det"
      )
      player = create_player(team: current_team, attributes: { mlb_id: 999123, first_name: "Jordan", last_name: "Legacy" })
      war = create_stat_type(name: "war", label: "WAR", category: "batting")

      create_player_season_stat(
        player: player,
        stat_type: war,
        attributes: { season: 2024, team: historical_team, value: 4.2 }
      )

      query = described_class.new(
        params: {
          filter: { team_id: historical_team.id, season: 2024 }
        }
      )

      expect(query.results.map(&:player_id)).to eq([player.id])
      expect(query.results.map(&:team_id)).to eq([historical_team.id])
    end

    it "filters by scope type and key" do
      player = create_player
      stat_type = create_stat_type(name: "ops", label: "OPS", category: "batting")

      create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 2024, value: 0.82 })
      create_player_season_stat(
        player: player,
        stat_type: stat_type,
        attributes: { season: 2024, team: nil, scope_type: "combined", scope_key: "TOT", value: 0.9 }
      )

      query = described_class.new(params: { filter: { scope_type: "combined", scope_key: "TOT" } })

      expect(query.results.count).to eq(1)
      expect(query.results.first.scope_type).to eq("combined")
      expect(query.results.first.scope_key).to eq("TOT")
    end
  end
end
