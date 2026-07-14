require "rails_helper"

RSpec.describe TeamMembership, type: :model do
  it "is valid with required effective-dated fields" do
    expect(create_team_membership).to be_valid
  end

  it "requires starts_on, roster_status, source_name, and last_synced_at" do
    membership = described_class.new(
      player: create_player,
      team: create_team,
      starts_on: nil,
      roster_status: nil,
      source_name: nil,
      last_synced_at: nil
    )

    expect(membership).not_to be_valid
    expect(membership.errors[:starts_on]).to include("can't be blank")
    expect(membership.errors[:roster_status]).to include("can't be blank")
    expect(membership.errors[:source_name]).to include("can't be blank")
    expect(membership.errors[:last_synced_at]).to include("can't be blank")
  end

  it "validates effective date windows" do
    membership = described_class.new(
      player: create_player,
      team: create_team,
      starts_on: Date.new(2026, 6, 15),
      ends_on: Date.new(2026, 6, 14),
      roster_status: "active",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(membership).not_to be_valid
    expect(membership.errors[:ends_on]).to include("must be on or after starts_on")
  end

  it "returns memberships active on a given date" do
    current = create_team_membership(starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 30))
    _inactive = create_team_membership(starts_on: Date.new(2026, 7, 1), ends_on: nil)

    expect(described_class.active_on(Date.new(2026, 6, 15))).to include(current)
    expect(described_class.active_on(Date.new(2026, 6, 15)).count).to eq(1)
  end

  it "prevents overlapping windows for the same player, team, and roster_status" do
    player = create_player
    team = player.team

    create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 30),
      roster_status: "active"
    )

    overlap = described_class.new(
      player: player,
      team: team,
      starts_on: Date.new(2026, 6, 15),
      ends_on: Date.new(2026, 7, 15),
      roster_status: "active",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(overlap).not_to be_valid
    expect(overlap.errors[:starts_on]).to include("overlaps another membership for this player/team/roster_status")
  end

  it "allows overlapping windows for different roster statuses" do
    player = create_player
    team = player.team

    create_team_membership(
      player: player,
      team: team,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 30),
      roster_status: "active"
    )

    overlap_different_status = described_class.new(
      player: player,
      team: team,
      starts_on: Date.new(2026, 6, 15),
      ends_on: Date.new(2026, 7, 15),
      roster_status: "40-man",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(overlap_different_status).to be_valid
  end
end