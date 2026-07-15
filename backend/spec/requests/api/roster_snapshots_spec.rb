require "rails_helper"

RSpec.describe "Api::RosterSnapshots", type: :request do
  it "returns both roster views for a team and exact date" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(
      team: team,
      attributes: { mlb_id: 592_450, first_name: "Aaron", last_name: "Judge" }
    )
    snapshot_on = Date.new(2026, 7, 15)

    %w[active 40Man].each do |roster_type|
      snapshot = RosterSnapshot.create!(
        team: team,
        season: 2026,
        roster_type: roster_type,
        snapshot_on: snapshot_on,
        source_name: "MLB Stats API",
        source_url: "https://statsapi.mlb.com/roster",
        last_synced_at: Time.zone.parse("2026-07-15T12:00:00Z")
      )
      snapshot.roster_snapshot_players.create!(
        player: player,
        mlb_id: player.mlb_id,
        full_name: player.full_name,
        jersey_number: "99",
        position_code: "RF",
        status_code: "A",
        status_description: "Active"
      )
    end

    get api_roster_snapshots_path, params: { team_mlb_id: 116, on: snapshot_on.iso8601 }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("roster_type")).to contain_exactly("40Man", "active")
    expect(json_body.dig("data", 0, "players", 0)).to include(
      "player_id" => player.id,
      "mlb_id" => 592_450,
      "full_name" => "Aaron Judge"
    )
    expect(json_body.dig("meta", "missing_roster_types")).to eq([])
  end

  it "reports missing roster views without falling back to another date" do
    team = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")

    get api_roster_snapshots_path, params: { team_mlb_id: team.mlb_id, on: "2026-07-14" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to eq([])
    expect(json_body.dig("meta", "missing_roster_types")).to contain_exactly("40Man", "active")
  end

  it "requires a valid date and team" do
    get api_roster_snapshots_path, params: { on: "not-a-date" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("On must be a valid ISO date")
  end
end
