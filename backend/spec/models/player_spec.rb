require "rails_helper"

RSpec.describe Player, type: :model do
  it "is valid with an mlb id, names, and team" do
    expect(create_player).to be_valid
  end

  it "requires a unique mlb id" do
    team = create_team
    create_player(team: team, attributes: { mlb_id: 408234 })

    duplicate = described_class.new(mlb_id: 408234, first_name: "Another", last_name: "Player", team: team)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mlb_id]).to include("has already been taken")
  end

  it "requires first and last name" do
    player = described_class.new(mlb_id: 408234, first_name: nil, last_name: nil, team: create_team)

    expect(player).not_to be_valid
    expect(player.errors[:first_name]).to include("can't be blank")
    expect(player.errors[:last_name]).to include("can't be blank")
  end
end
