require "rails_helper"

RSpec.describe "Api::TeamMemberships", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    @dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lad",
      file_code: "lad"
    )
    @miguel = create_player(team: @tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    @shohei = create_player(team: @dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })
  end

  it "returns active memberships for a given day" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @dodgers,
      starts_on: Date.new(2026, 7, 1),
      ends_on: nil,
      roster_status: "active"
    )

    get active_today_api_team_memberships_path,
        params: { on: "2026-06-15" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "on")).to eq("2026-06-15")
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.fetch("data").map { |row| row.dig("player", "full_name") }).to eq(["Miguel Cabrera"])
    expect(json_body.dig("data", 0, "roster_status")).to eq("active")
  end

  it "applies top-level team_id and roster_status filters for active_today" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @dodgers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "40-man"
    )

    get active_today_api_team_memberships_path,
        params: { on: "2026-06-15", team_id: @tigers.id, roster_status: "active" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.fetch("data").map { |row| row.dig("player", "full_name") }).to eq(["Miguel Cabrera"])
  end

  it "returns memberships overlapping a date range (series window)" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 15),
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @dodgers,
      starts_on: Date.new(2026, 6, 18),
      ends_on: nil,
      roster_status: "active"
    )

    get active_range_api_team_memberships_path,
        params: { starts_on: "2026-06-10", ends_on: "2026-06-20" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "starts_on")).to eq("2026-06-10")
    expect(json_body.dig("meta", "ends_on")).to eq("2026-06-20")
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.fetch("data").map { |row| row.dig("player", "full_name") }).to contain_exactly("Miguel Cabrera", "Shohei Ohtani")
  end

  it "applies top-level team_id and roster_status filters for active_range" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 30),
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @dodgers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 30),
      roster_status: "active"
    )

    get active_range_api_team_memberships_path,
        params: { starts_on: "2026-06-10", ends_on: "2026-06-20", team_id: @dodgers.id, roster_status: "active" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.fetch("data").map { |row| row.dig("player", "full_name") }).to eq(["Shohei Ohtani"])
  end

  it "returns grouped active versus 40-man memberships" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "40-man"
    )

    get roster_status_api_team_memberships_path,
        params: { on: "2026-06-15", team_id: @tigers.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "on")).to eq("2026-06-15")
    expect(json_body.dig("meta", "team_id")).to eq(@tigers.id)
    expect(json_body.dig("meta", "counts", "active")).to eq(1)
    expect(json_body.dig("meta", "counts", "40-man")).to eq(1)
    expect(json_body.dig("data", "active", 0, "player", "full_name")).to eq("Miguel Cabrera")
    expect(json_body.dig("data", "40-man", 0, "player", "full_name")).to eq("Shohei Ohtani")
  end

  it "applies top-level player_id and roster_status filters for roster_status" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "40-man"
    )

    get roster_status_api_team_memberships_path,
        params: { on: "2026-06-15", team_id: @tigers.id, player_id: @miguel.id, roster_status: "active" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "counts", "active")).to eq(1)
    expect(json_body.dig("meta", "counts").keys).to eq(["active"])
    expect(json_body.dig("meta", "statuses")).to eq(["active"])
    expect(json_body.dig("meta", "filters", "player_id")).to eq(@miguel.id)
    expect(json_body.dig("meta", "filters", "roster_status")).to eq("active")
    expect(json_body.dig("data", "active", 0, "player", "full_name")).to eq("Miguel Cabrera")
  end

  it "applies nested filter params for roster_status" do
    create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "active"
    )
    create_team_membership(
      player: @shohei,
      team: @tigers,
      starts_on: Date.new(2026, 6, 1),
      ends_on: nil,
      roster_status: "40-man"
    )

    get roster_status_api_team_memberships_path,
        params: { on: "2026-06-15", filter: { team_id: @tigers.id, player_id: @shohei.id, roster_status: "40-man" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "counts", "40-man")).to eq(1)
    expect(json_body.dig("meta", "counts").keys).to eq(["40-man"])
    expect(json_body.dig("meta", "statuses")).to eq(["40-man"])
    expect(json_body.dig("data", "40-man", 0, "player", "full_name")).to eq("Shohei Ohtani")
  end
end