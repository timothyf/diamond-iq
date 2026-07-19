require "rails_helper"

RSpec.describe MlbRosterSyncBoundary do
  let(:today) { Date.new(2026, 7, 15) }

  it "uses today for the current season" do
    expect(described_class.call(season: 2026, today: today)).to eq(today)
  end

  it "uses the final regular-season game date for a completed season" do
    tigers = create_team(mlb_id: 116, abbreviation: "DET")
    guardians = create_team(mlb_id: 114, abbreviation: "CLE")
    schedule = create_schedule(season: 2025, schedule_type: "R")
    create_game(
      schedule: schedule,
      home_team: tigers,
      away_team: guardians,
      official_date: Date.new(2025, 9, 28),
      game_type: "R"
    )

    expect(described_class.call(season: "2025", today: today, team_mlb_id: 116)).to eq(Date.new(2025, 9, 28))
  end

  it "falls back to December 31 when no schedule is stored" do
    expect(described_class.call(season: "2024", today: today)).to eq(Date.new(2024, 12, 31))
  end

  it "rejects future and invalid seasons" do
    expect { described_class.call(season: 2027, today: today) }.to raise_error(ArgumentError, "Season cannot be in the future")
    expect { described_class.call(season: "invalid", today: today) }.to raise_error(ArgumentError, "Season must be greater than 1800")
  end
end
