require "rails_helper"

RSpec.describe Roster, type: :model do
  it "is valid with a team and season" do
    roster = described_class.new(
      team: create_team,
      season: 2026,
      roster_type: "40Man",
      snapshot_on: Date.current,
      source_name: "derived_team_memberships",
      last_synced_at: Time.current
    )

    expect(roster).to be_valid
  end

  it "requires a team and season" do
    roster = described_class.new(team: nil, season: nil)

    expect(roster).not_to be_valid
    expect(roster.errors[:team]).to include("must exist")
    expect(roster.errors[:season]).to include("can't be blank")
  end

  it "requires team and season combinations to be unique" do
    team = create_team
    create_team_season_roster(team: team, season: 2026)

    duplicate = described_class.new(
      team: team,
      season: 2026,
      roster_type: "40Man",
      snapshot_on: Date.current,
      source_name: "derived_team_memberships",
      last_synced_at: Time.current
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:team_id]).to include("has already been taken")
  end

  it "exposes players through roster players" do
    roster = create_team_season_roster
    player = create_player
    RosterPlayer.create!(roster: roster, player: player)

    expect(roster.players).to contain_exactly(player)
  end

  it "rebuilds its player cache from active memberships" do
    team = create_team
    active_player = create_player(team: team)
    inactive_player = create_player(team: team)
    create_team_membership(player: active_player, team: team, starts_on: Date.new(2026, 4, 1))
    create_team_membership(
      player: inactive_player,
      team: team,
      starts_on: Date.new(2026, 3, 1),
      ends_on: Date.new(2026, 3, 31)
    )
    roster = create_team_season_roster(team: team)

    roster.rebuild_from_memberships!(
      on: Date.new(2026, 4, 15),
      roster_type: "40Man",
      source_name: "MLB Stats API",
      last_synced_at: Time.zone.parse("2026-04-15 12:00:00"),
      raw_data: { "roster" => [] }
    )

    expect(roster.reload.players).to contain_exactly(active_player)
    expect(roster.snapshot_on).to eq(Date.new(2026, 4, 15))
  end
end
