require "rails_helper"

RSpec.describe Roster, type: :model do
  it "is valid with a team and season" do
    roster = described_class.new(team: create_team, season: 2026)

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

    duplicate = described_class.new(team: team, season: 2026)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:team_id]).to include("has already been taken")
  end

  it "exposes players through roster players" do
    roster = create_team_season_roster
    player = create_player
    RosterPlayer.create!(roster: roster, player: player)

    expect(roster.players).to contain_exactly(player)
  end
end