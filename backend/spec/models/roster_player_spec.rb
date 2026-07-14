require "rails_helper"

RSpec.describe RosterPlayer, type: :model do
  it "is valid with a roster and player" do
    roster_player = described_class.new(roster: create_team_season_roster, player: create_player)

    expect(roster_player).to be_valid
  end

  it "requires roster and player" do
    roster_player = described_class.new(roster: nil, player: nil)

    expect(roster_player).not_to be_valid
    expect(roster_player.errors[:roster]).to include("must exist")
    expect(roster_player.errors[:player]).to include("must exist")
  end

  it "requires player to be unique within a roster" do
    roster = create_team_season_roster
    player = create_player
    described_class.create!(roster: roster, player: player)

    duplicate = described_class.new(roster: roster, player: player)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:player_id]).to include("has already been taken")
  end
end