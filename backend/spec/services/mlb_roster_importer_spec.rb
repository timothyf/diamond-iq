require "rails_helper"

RSpec.describe MlbRosterImporter do
  let(:team) { create_team(mlb_id: 116, abbreviation: "DET") }
  let(:fetched_at) { Time.zone.parse("2026-07-14 12:00:00") }

  def roster_entry(
    player_id: 680_776,
    status_code: "A",
    status_description: "Active",
    jersey_number: "24"
  )
    {
      "person" => {
        "id" => player_id,
        "fullName" => "Riley Greene",
        "firstName" => "Riley",
        "lastName" => "Greene",
        "useName" => "Riley",
        "useLastName" => "Greene",
        "birthDate" => "2000-09-28",
        "height" => "6' 3\"",
        "weight" => 200,
        "mlbDebutDate" => "2022-06-18",
        "batSide" => { "code" => "L" },
        "pitchHand" => { "code" => "L" },
        "primaryPosition" => {
          "code" => "8",
          "name" => "Outfielder",
          "type" => "Outfielder",
          "abbreviation" => "CF"
        }
      },
      "jerseyNumber" => jersey_number,
      "position" => {
        "code" => "8",
        "name" => "Outfielder",
        "type" => "Outfielder",
        "abbreviation" => "CF"
      },
      "status" => {
        "code" => status_code,
        "description" => status_description
      }
    }
  end

  def import(payload:, import_team: team, as_of: Date.new(2026, 7, 14), at: fetched_at)
    described_class.call(
      payload: payload,
      team_mlb_id: import_team.mlb_id,
      season: 2026,
      as_of: as_of,
      source_url: "https://statsapi.mlb.com/api/v1/teams/#{import_team.mlb_id}/roster",
      fetched_at: at
    )
  end

  it "idempotently synchronizes profiles, positions, memberships, and the roster cache" do
    payload = { "roster" => [ roster_entry ] }

    first_result = import(payload: payload)
    second_result = import(payload: payload, at: fetched_at + 1.hour)

    expect(first_result[:success]).to be(true)
    expect(second_result[:success]).to be(true)
    expect(Player.where(mlb_id: 680_776).count).to eq(1)
    expect(PlayerProfile.count).to eq(1)
    expect(TeamMembership.count).to eq(1)
    expect(PlayerPosition.count).to eq(2)
    expect(Roster.count).to eq(1)
    expect(RosterPlayer.count).to eq(1)

    player = Player.find_by!(mlb_id: 680_776)
    expect(player).to have_attributes(first_name: "Riley", last_name: "Greene", team_id: team.id)
    expect(player.profile).to have_attributes(
      height_inches: 75,
      weight_pounds: 200,
      bats: "L",
      throws: "L",
      source_name: "MLB Stats API"
    )
    expect(player.primary_position).to have_attributes(mlb_code: "8", abbreviation: "CF")
    expect(player.primary_position(season: 2026)).to eq(player.primary_position)

    membership = player.team_memberships.sole
    expect(membership).to have_attributes(
      starts_on: Date.new(2026, 7, 14),
      ends_on: nil,
      roster_status: "active",
      jersey_number: "24",
      source_status_code: "A"
    )
    expect(membership.raw_data).to eq(roster_entry)
    expect(team.rosters.sole.players).to contain_exactly(player)
    expect(second_result.dig(:data, :created_membership_count)).to eq(0)
    expect(second_result.dig(:data, :updated_membership_count)).to eq(1)
  end

  it "closes the previous status window when a player's status changes" do
    import(payload: { "roster" => [ roster_entry ] })

    result = import(
      payload: {
        "roster" => [ roster_entry(status_code: "D10", status_description: "Injured 10-Day") ]
      },
      as_of: Date.new(2026, 7, 20),
      at: fetched_at + 6.days
    )

    expect(result[:success]).to be(true)
    memberships = Player.find_by!(mlb_id: 680_776).team_memberships.order(:starts_on)
    expect(memberships.first).to have_attributes(
      roster_status: "active",
      ends_on: Date.new(2026, 7, 19)
    )
    expect(memberships.last).to have_attributes(
      roster_status: "injured_10_day",
      starts_on: Date.new(2026, 7, 20),
      ends_on: nil
    )
    expect(memberships.last).to be_injured
  end

  it "closes an MLB membership when a player is missing from a later snapshot" do
    import(payload: { "roster" => [ roster_entry ] })

    result = import(
      payload: { "roster" => [] },
      as_of: Date.new(2026, 7, 21),
      at: fetched_at + 7.days
    )

    expect(result[:success]).to be(true)
    expect(TeamMembership.sole.ends_on).to eq(Date.new(2026, 7, 20))
    expect(team.rosters.sole.players).to be_empty
  end

  it "closes a prior team window and refreshes players.team_id after a transfer" do
    import(payload: { "roster" => [ roster_entry ] })
    new_team = create_team(mlb_id: 147, abbreviation: "NYY")

    result = import(
      payload: { "roster" => [ roster_entry(jersey_number: "31") ] },
      import_team: new_team,
      as_of: Date.new(2026, 7, 25),
      at: fetched_at + 11.days
    )

    expect(result[:success]).to be(true)
    player = Player.find_by!(mlb_id: 680_776)
    expect(player.reload.team).to eq(new_team)
    expect(player.team_memberships.find_by!(team: team).ends_on).to eq(Date.new(2026, 7, 24))
    expect(player.team_memberships.find_by!(team: new_team)).to have_attributes(
      starts_on: Date.new(2026, 7, 25),
      jersey_number: "31"
    )
  end

  it "rolls back the snapshot when a roster entry fails validation" do
    result = import(payload: { "roster" => [ roster_entry, { "person" => {} } ] })

    expect(result[:success]).to be(false)
    expect(result.dig(:data, :errors)).to include("Roster entry is missing person.id")
    expect(Player.count).to eq(0)
    expect(TeamMembership.count).to eq(0)
    expect(Roster.count).to eq(0)
  end

  it "rejects an older snapshot without changing inferred membership windows" do
    import(payload: { "roster" => [ roster_entry ] })

    result = import(
      payload: { "roster" => [] },
      as_of: Date.new(2026, 7, 13),
      at: fetched_at + 1.hour
    )

    expect(result[:success]).to be(false)
    expect(result.dig(:data, :errors).join).to include("before existing snapshot")
    expect(TeamMembership.sole.ends_on).to be_nil
  end

  it "places a historical snapshot before known future membership without changing the current team" do
    current_team = create_team(mlb_id: 147, abbreviation: "NYY")
    player = create_player(
      team: current_team,
      attributes: { mlb_id: 680_776, first_name: "Riley", last_name: "Greene" }
    )
    current_membership = create_team_membership(
      player: player,
      team: current_team,
      starts_on: Date.new(2026, 3, 26),
      roster_status: "active"
    )

    result = described_class.call(
      payload: { "roster" => [ roster_entry ] },
      team_mlb_id: team.mlb_id,
      season: 2025,
      as_of: Date.new(2025, 12, 31),
      source_url: "https://statsapi.mlb.com/api/v1/teams/116/roster",
      fetched_at: fetched_at
    )

    expect(result[:success]).to be(true)
    historical_membership = player.team_memberships.find_by!(team: team)
    expect(historical_membership).to have_attributes(
      starts_on: Date.new(2025, 12, 31),
      ends_on: Date.new(2026, 3, 25)
    )
    expect(current_membership.reload.ends_on).to be_nil
    expect(player.reload.team).to eq(current_team)
    expect(team.rosters.find_by!(season: 2025).snapshot_on).to eq(Date.new(2025, 12, 31))
  end
end
