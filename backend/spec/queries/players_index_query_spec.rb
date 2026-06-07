require "rails_helper"

RSpec.describe PlayersIndexQuery, type: :model do
  describe "#results" do
    it "filters by team id and sorts by last name" do
      tigers = create_team(mlb_id: 116, team_name: "Tigers", name: "Detroit Tigers", abbreviation: "DET", location_name: "Detroit", short_name: "Detroit", team_code: "det", file_code: "det")
      dodgers = create_team(mlb_id: 119, team_name: "Dodgers", name: "Los Angeles Dodgers", abbreviation: "LAD", location_name: "Los Angeles", short_name: "Los Angeles", team_code: "lan", file_code: "la")

      create_player(team: tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
      create_player(team: tigers, attributes: { mlb_id: 592450, first_name: "Riley", last_name: "Greene" })
      create_player(team: dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })

      query = described_class.new(params: { filter: { team_id: tigers.id }, sort: "last_name" })

      expect(query.results.map(&:last_name)).to eq(%w[Cabrera Greene])
      expect(query.metadata[:filters]).to eq(team_id: tigers.id)
    end

    it "normalizes invalid pagination and sort values" do
      team = create_team
      create_player(team: team, attributes: { last_name: "Zulu" })
      create_player(team: team, attributes: { last_name: "Alpha" })

      query = described_class.new(params: { page: 0, per_page: 500, sort: "not_a_field" })

      expect(query.results.map(&:last_name)).to eq(%w[Alpha Zulu])
      expect(query.metadata[:page]).to eq(1)
      expect(query.metadata[:per_page]).to eq(100)
      expect(query.metadata[:sort]).to eq("last_name")
    end

    it "filters by a combined player name query across first and last name" do
      team = create_team
      create_player(team: team, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
      create_player(team: team, attributes: { mlb_id: 545361, first_name: "Mike", last_name: "Trout" })

      expect(described_class.new(params: { filter: { name: "mig" } }).results.map(&:first_name)).to eq(["Miguel"])
      expect(described_class.new(params: { filter: { name: "out" } }).results.map(&:last_name)).to eq(["Trout"])
      expect(described_class.new(params: { filter: { name: "Miguel Cabrera" } }).results.map(&:last_name)).to eq(["Cabrera"])
    end
  end
end
