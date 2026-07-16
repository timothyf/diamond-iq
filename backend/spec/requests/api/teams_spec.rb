require "rails_helper"

RSpec.describe "Api::Teams", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    @guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    @schedule = create_schedule(season: Date.current.year, schedule_type: "R")
  end

  it "lists teams for the team directory" do
    get api_teams_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.fetch("data").map { |team| team.fetch("name") }).to eq([ "Cleveland Guardians", "Detroit Tigers" ])
    expect(json_body.dig("data", 1, "logo_url")).to eq("https://www.mlbstatic.com/team-logos/116.svg")
  end

  it "returns a unified roster, record, and schedule profile" do
    player = create_player(team: @tigers, attributes: { mlb_id: 680_776, first_name: "Riley", last_name: "Greene" })
    create_player_profile(player: player, attributes: { headshot_id: "680776" })
    membership = create_team_membership(
      player: player,
      team: @tigers,
      starts_on: Date.current - 30.days,
      roster_status: "active",
      jersey_number: "31",
      primary_position: "CF",
      source_status_description: "Active"
    )
    optioned_player = create_player(team: @tigers, attributes: { mlb_id: 679_529, first_name: "Spencer", last_name: "Torkelson" })
    optioned_membership = create_team_membership(
      player: optioned_player,
      team: @tigers,
      starts_on: Date.current - 20.days,
      roster_status: "minors",
      jersey_number: "20",
      primary_position: "1B",
      source_status_description: "Minors"
    )
    completed_game = create_game(
      schedule: @schedule,
      home_team: @tigers,
      away_team: @guardians,
      official_date: Date.current - 1.day,
      status: "final",
      home_score: 5,
      away_score: 2
    )
    upcoming_game = create_game(
      schedule: @schedule,
      home_team: @guardians,
      away_team: @tigers,
      official_date: Date.current + 1.day,
      status: "scheduled",
      venue_name: "Progressive Field"
    )

    get api_team_path(@tigers)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "name")).to eq("Detroit Tigers")
    expect(json_body.dig("data", "season")).to eq(Date.current.year)
    expect(json_body.dig("data", "record")).to include(
      "wins" => 1,
      "losses" => 0,
      "games_played" => 1,
      "runs_scored" => 5,
      "runs_allowed" => 2
    )
    serialized_membership = json_body.dig("data", "roster").find { |entry| entry.fetch("id") == membership.id }
    expect(serialized_membership).to include(
      "id" => membership.id,
      "jersey_number" => "31",
      "primary_position" => "CF"
    )
    expect(serialized_membership.dig("player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "roster_as_of")).to eq(Date.current.iso8601)
    expect(json_body.dig("data", "rosters", "forty_man").pluck("id")).to contain_exactly(membership.id, optioned_membership.id)
    expect(json_body.dig("data", "rosters", "active").pluck("id")).to eq([ membership.id ])
    expect(json_body.dig("data", "roster_summary")).to include(
      "total" => 2,
      "active" => 1,
      "other" => 1
    )
    expect(json_body.dig("data", "recent_games", 0, "id")).to eq(completed_game.id)
    expect(json_body.dig("data", "upcoming_games", 0, "id")).to eq(upcoming_game.id)
    expect(json_body.dig("data", "source_metadata", "roster_last_synced_at")).to be_present
  end

  it "selects a requested season" do
    old_schedule = create_schedule(
      season: 2025,
      start_date: Date.new(2025, 3, 27),
      end_date: Date.new(2025, 9, 28),
      source_key: "mlb:2025:regular"
    )
    create_game(
      schedule: old_schedule,
      home_team: @tigers,
      away_team: @guardians,
      official_date: Date.new(2025, 7, 1),
      status: "final",
      home_score: 1,
      away_score: 3
    )

    get api_team_path(@tigers), params: { season: 2025 }

    expect(json_body.dig("data", "season")).to eq(2025)
    expect(json_body.dig("data", "record", "losses")).to eq(1)
    expect(json_body.dig("data", "available_seasons")).to include(2025)
  end
end
