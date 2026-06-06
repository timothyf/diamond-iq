require "rails_helper"

RSpec.describe PlayerSeasonStat, type: :model do
  it "is valid with a player, stat type, season, and numeric value" do
    expect(create_player_season_stat).to be_valid
  end

  it "requires season and numeric value" do
    stat = described_class.new(player: create_player, stat_type: create_stat_type, season: nil, value: "abc")

    expect(stat).not_to be_valid
    expect(stat.errors[:season]).to include("can't be blank")
    expect(stat.errors[:value]).to include("is not a number")
  end
end
