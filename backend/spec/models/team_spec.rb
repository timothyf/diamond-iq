require "rails_helper"

RSpec.describe Team, type: :model do
  it "is valid with all required fields" do
    expect(create_team).to be_valid
  end

  it "requires a unique mlb id" do
    create_team(mlb_id: 116)

    duplicate = described_class.new(
      mlb_id: 116,
      name: "Another Team",
      abbreviation: "AT",
      team_name: "Another",
      location_name: "Elsewhere",
      short_name: "Elsewhere",
      team_code: "another",
      file_code: "another"
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mlb_id]).to include("has already been taken")
  end

  it "requires core display fields" do
    team = described_class.new(mlb_id: nil)

    expect(team).not_to be_valid
    expect(team.errors[:mlb_id]).to include("can't be blank")
    expect(team.errors[:name]).to include("can't be blank")
    expect(team.errors[:abbreviation]).to include("can't be blank")
    expect(team.errors[:team_name]).to include("can't be blank")
  end
end
