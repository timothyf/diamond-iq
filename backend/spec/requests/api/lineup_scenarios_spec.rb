require "rails_helper"

RSpec.describe "Api::LineupScenarios", type: :request do
  let(:team) { create_team(name: "Detroit Tigers", abbreviation: "DET") }
  let(:season) { Date.current.year }
  let(:owner) { create_user(role: "coach") }
  let(:headers) { user_headers(owner) }

  def active_players
    @active_players ||= 9.times.map do |index|
      player = create_player(team: team, attributes: { first_name: "Player", last_name: "#{index + 1}" })
      create_team_membership(player: player, team: team, starts_on: Date.current - 1.day, roster_status: "active")
      player
    end
  end

  def valid_entries
    LineupScenarioEntry::DEFENSIVE_POSITIONS.each_with_index.map do |position, index|
      { player_id: active_players[index].id, batting_slot: index + 1, defensive_position: position }
    end
  end

  it "saves a complete constraint-valid lineup scenario and returns it" do
    post api_team_lineup_scenarios_path(team), params: {
      season: season,
      scenario_date: Date.current.iso8601,
      name: "Vs right-handed starter",
      notes: "Favor on-base skills early.",
      evaluation_inputs: {
        opponent: "Cleveland Guardians",
        opponent_strength: 65,
        park_factor: 105,
        pitcher_hand: "R",
        recent_performance: 78,
        reliability: 88
      },
      entries: valid_entries
    }, headers: headers

    expect(response).to have_http_status(:created)
    scenario_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "owner", "id")).to eq(owner.id)
    expect(json_body.dig("data", "entries").map { |entry| entry.fetch("batting_slot") }).to eq((1..9).to_a)
    expect(json_body.dig("data", "entries").map { |entry| entry.fetch("defensive_position") }).to match_array(LineupScenarioEntry::DEFENSIVE_POSITIONS)
    expect(json_body.dig("data", "evaluation_inputs", "opponent")).to eq("Cleveland Guardians")
    expect(json_body.dig("data", "total_score")).to be_between(0, 100)
    expect(json_body.dig("data", "score_breakdown")).to include(
      "opponent", "park", "platoon", "recent_performance", "reliability"
    )

    get api_team_lineup_scenarios_path(team), params: { season: season }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "id")).to eq(scenario_id)
    expect(json_body.dig("data", 0, "total_score")).to be_between(0, 100)

    get api_lineup_scenario_path(scenario_id), headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "name")).to eq("Vs right-handed starter")

    patch api_lineup_scenario_path(scenario_id), params: { notes: "Updated game-plan notes." }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "notes")).to eq("Updated game-plan notes.")

    get audit_history_api_lineup_scenario_path(scenario_id), headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("action")).to eq(%w[updated created])
    expect(json_body.dig("data", 0, "user", "id")).to eq(owner.id)
  end

  it "recommends an explainable order while honoring locks and exclusions" do
    players = active_players
    extra = create_player(team: team, attributes: { first_name: "Extra", last_name: "Player" })
    create_team_membership(player: extra, team: team, starts_on: Date.current - 1.day, roster_status: "active")
    players << extra
    post recommend_api_team_lineup_scenarios_path(team), params: {
      season: season,
      scenario_date: Date.current.iso8601,
      evaluation_inputs: { pitcher_hand: "R" },
      decision_constraints: {
        locked_batting_order: { players[0].id.to_s => 1 },
        excluded_player_ids: [ players[8].id ],
        required_starter_ids: [ players[0].id ]
      },
      decision_weights: { production: 60, platoon: 20, recent: 10, reliability: 10 },
      alternative_count: 2
    }, headers: headers

    expect(response).to have_http_status(:ok)
    data = json_body.fetch("data")
    expect(data.fetch("recommended").length).to eq(9)
    expect(data.fetch("recommended").map { |entry| entry.fetch("defensive_position") }).to match_array(LineupScenarioEntry::DEFENSIVE_POSITIONS)
    expect(data.dig("recommended", 0, "player_id")).to eq(players[0].id)
    expect(data.fetch("recommended").map { |entry| entry.fetch("player_id") }).not_to include(players[8].id)
    expect(data.fetch("alternatives").length).to eq(2)
    expect(data.fetch("explanation").join(" ")).to include("production")
  end

  it "excludes pitchers from recommendations and rejects them in saved lineups" do
    active_players
    pitcher = create_player(team: team, attributes: { first_name: "Starting", last_name: "Pitcher" })
    create_team_membership(player: pitcher, team: team, starts_on: Date.current - 1.day, roster_status: "active", attributes: { primary_position: "P" })
    post recommend_api_team_lineup_scenarios_path(team), params: { season: season, scenario_date: Date.current.iso8601 }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "recommended").map { |entry| entry.fetch("player_id") }).not_to include(pitcher.id)

    entries = valid_entries
    entries[0][:player_id] = pitcher.id
    post api_team_lineup_scenarios_path(team), params: { season: season, scenario_date: Date.current.iso8601, name: "Pitcher lineup", entries: entries }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("violations")).to include("Pitchers cannot be included in batting lineups.")
  end

  it "rejects duplicate players, invalid defensive coverage, and unavailable players" do
    entries = valid_entries
    entries[1][:player_id] = entries[0][:player_id]
    entries[2][:defensive_position] = "C"

    post api_team_lineup_scenarios_path(team), params: {
      season: season,
      scenario_date: Date.current.iso8601,
      name: "Invalid scenario",
      entries: entries
    }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("violations")).to include(
      "Each player can appear only once in a lineup.",
      "Assign exactly one C, 1B, 2B, 3B, SS, LF, CF, RF, and DH."
    )
    expect(LineupScenario.count).to eq(0)
  end

  it "requires authentication and isolates scenarios by owner while allowing administrator oversight" do
    scenario = LineupScenario.create!(
      team: team,
      owner: owner,
      season: season,
      scenario_date: Date.current,
      name: "Private lineup"
    )

    get api_lineup_scenario_path(scenario)
    expect(response).to have_http_status(:unauthorized)

    other_user = create_user(role: "scout")
    get api_team_lineup_scenarios_path(team), headers: user_headers(other_user)
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to be_empty

    get api_lineup_scenario_path(scenario), headers: user_headers(other_user)
    expect(response).to have_http_status(:forbidden)

    patch api_lineup_scenario_path(scenario), params: { notes: "Unauthorized change" }, headers: user_headers(other_user)
    expect(response).to have_http_status(:forbidden)
    expect(scenario.reload.notes).to be_nil

    admin = create_user(role: "administrator")
    get api_lineup_scenario_path(scenario), headers: user_headers(admin)
    expect(response).to have_http_status(:ok)
  end

  it "does not allow viewers to create lineup scenarios" do
    viewer = create_user(role: "viewer")

    post api_team_lineup_scenarios_path(team), params: {
      season: season,
      scenario_date: Date.current.iso8601,
      name: "Viewer lineup",
      entries: valid_entries
    }, headers: user_headers(viewer)

    expect(response).to have_http_status(:forbidden)
    expect(LineupScenario.count).to eq(0)
  end
end
