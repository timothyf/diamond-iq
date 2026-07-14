require "rails_helper"

RSpec.describe "Api::PlayerPositions", type: :request do
  it "returns current and historical position assignments with a current summary" do
    player = create_player(attributes: { first_name: "Miguel", last_name: "Cabrera" })
    first_base = create_position(
      mlb_code: "3",
      abbreviation: "1B",
      name: "First Base",
      position_type: "infielder",
      sort_order: 3
    )
    third_base = create_position(
      mlb_code: "5",
      abbreviation: "3B",
      name: "Third Base",
      position_type: "infielder",
      sort_order: 5
    )

    create_player_position(player: player, position: first_base, attributes: { is_primary: true })
    create_player_position(player: player, position: third_base)
    create_player_position(
      player: player,
      position: third_base,
      attributes: { season: 2024, is_primary: true }
    )

    get api_player_path(player)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "positions", "primary", "abbreviation")).to eq("1B")
    expect(json_body.dig("data", "positions", "secondary").map { |position| position.fetch("abbreviation") }).to eq(["3B"])

    assignments = json_body.dig("data", "positions", "assignments")
    expect(assignments.map { |assignment| assignment.fetch("season") }).to eq([nil, nil, 2024])
    expect(assignments.map { |assignment| assignment.fetch("primary") }).to eq([true, false, true])
    expect(assignments.last.dig("position", "name")).to eq("Third Base")
  end
end
