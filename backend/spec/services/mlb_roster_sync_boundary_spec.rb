require "rails_helper"

RSpec.describe MlbRosterSyncBoundary do
  let(:today) { Date.new(2026, 7, 15) }

  it "uses today for the current season" do
    expect(described_class.call(season: 2026, today: today)).to eq(today)
  end

  it "uses December 31 for a completed season" do
    expect(described_class.call(season: "2025", today: today)).to eq(Date.new(2025, 12, 31))
  end

  it "rejects future and invalid seasons" do
    expect { described_class.call(season: 2027, today: today) }.to raise_error(ArgumentError, "Season cannot be in the future")
    expect { described_class.call(season: "invalid", today: today) }.to raise_error(ArgumentError, "Season must be greater than 1800")
  end
end
