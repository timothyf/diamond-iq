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
  end
end
