require "rails_helper"

RSpec.describe "Api::LineupScenarios", type: :request do
  let(:team) { create_team(name: "Detroit Tigers", abbreviation: "DET") }
  let(:season) { Date.current.year }

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
      entries: valid_entries
    }

    expect(response).to have_http_status(:created)
    scenario_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "entries").map { |entry| entry.fetch("batting_slot") }).to eq((1..9).to_a)
    expect(json_body.dig("data", "entries").map { |entry| entry.fetch("defensive_position") }).to match_array(LineupScenarioEntry::DEFENSIVE_POSITIONS)

    get api_team_lineup_scenarios_path(team), params: { season: season }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "id")).to eq(scenario_id)

    get api_lineup_scenario_path(scenario_id)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "name")).to eq("Vs right-handed starter")
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
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("violations")).to include(
      "Each player can appear only once in a lineup.",
      "Assign exactly one C, 1B, 2B, 3B, SS, LF, CF, RF, and DH."
    )
    expect(LineupScenario.count).to eq(0)
  end
end
