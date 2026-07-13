require "rails_helper"

RSpec.describe Game, type: :model do
  it "is valid with canonical matchup and source fields" do
    expect(create_game).to be_valid
  end

  it "requires a unique MLB game id to prevent duplicate games" do
    game = create_game(mlb_id: 777_001)
    duplicate = described_class.new(game.attributes.except("id", "created_at", "updated_at"))

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:mlb_id]).to include("has already been taken")
  end

  it "requires different home and away teams" do
    team = create_team
    game = described_class.new(
      schedule: create_schedule,
      mlb_id: 777_002,
      official_date: Date.current,
      game_type: "R",
      status: "scheduled",
      home_team: team,
      away_team: team,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(game).not_to be_valid
    expect(game.errors[:away_team]).to include("must be different from the home team")
  end

  it "supports probable pitchers for opponent preparation" do
    home_team = create_team
    away_team = create_team
    home_pitcher = create_player(team: home_team)
    away_pitcher = create_player(team: away_team)

    game = create_game(
      home_team: home_team,
      away_team: away_team,
      home_probable_pitcher: home_pitcher,
      away_probable_pitcher: away_pitcher
    )

    expect(game.home_probable_pitcher).to eq(home_pitcher)
    expect(game.away_probable_pitcher).to eq(away_pitcher)
  end
end
