require "rails_helper"

RSpec.describe PlayerPositionsBackfill do
  it "creates normalized current assignments from the latest team membership" do
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
    left_field = create_position(
      mlb_code: "7",
      abbreviation: "LF",
      name: "Left Field",
      position_type: "outfielder",
      sort_order: 7
    )

    player = create_player
    create_player_position(player: player, position: left_field, attributes: { is_primary: true })
    membership = create_team_membership(
      player: player,
      team: player.team,
      primary_position: "1B",
      secondary_positions: ["3B"]
    )

    result = described_class.call(relation: TeamMembership.where(id: membership.id))

    expect(result[:success]).to be(true)
    expect(player.player_positions.current.count).to eq(2)
    expect(player.player_positions.current.primary_assignments.first.position).to eq(first_base)
    expect(player.player_positions.current.secondary_assignments.first.position).to eq(third_base)
    expect(player.player_positions.current.where(position: left_field)).to be_empty
    expect(result.dig(:data, :assignments_deleted)).to eq(1)
  end

  it "preserves existing assignments when the membership contains an unknown position code" do
    left_field = create_position(
      mlb_code: "7",
      abbreviation: "LF",
      name: "Left Field",
      position_type: "outfielder",
      sort_order: 7
    )
    player = create_player
    existing = create_player_position(player: player, position: left_field, attributes: { is_primary: true })
    membership = create_team_membership(
      player: player,
      team: player.team,
      primary_position: "UNKNOWN",
      secondary_positions: []
    )

    result = described_class.call(relation: TeamMembership.where(id: membership.id))

    expect(result[:success]).to be(true)
    expect(player.player_positions.current).to contain_exactly(existing)
    expect(result.dig(:data, :unknown_position_codes)).to eq(["UNKNOWN"])
    expect(result.dig(:data, :assignments_deleted)).to eq(0)
  end
end
