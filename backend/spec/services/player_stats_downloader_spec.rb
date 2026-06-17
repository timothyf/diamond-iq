require "rails_helper"
require "csv"

RSpec.describe PlayerStatsDownloader, type: :service do
  it "downloads MLB batting rows and returns import-ready csv data" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          {
            "playerId" => 408234,
            "playerName" => "Miguel Cabrera",
            "firstName" => "Miguel",
            "lastName" => "Cabrera",
            "teamId" => 116,
            "teamAbbrev" => "DET",
            "teamName" => "Detroit Tigers",
            "teamShortName" => "Tigers",
            "gamesPlayed" => 140,
            "homeRuns" => 31,
            "ops" => ".920"
          }
        ]
      }
    )

    result = downloader.call
    csv = CSV.parse(result.dig(:data, :csv_data), headers: true)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :row_count)).to eq(1)
    expect(csv.headers).to include("source_season", "stat_type", "playerFirstName", "playerLastName", "teamName")
    expect(csv.first["stat_type"]).to eq("batter")
    expect(csv.first["season"]).to eq("2026")
    expect(csv.first["playerFirstName"]).to eq("Miguel")
  end

  it "normalizes pitcher aliases and validates the year range" do
    bad_range = described_class.call(category: "pitching", start_year: 2026, end_year: 2025)

    expect(bad_range[:success]).to be(false)
    expect(bad_range[:message]).to eq("End year must be greater than or equal to start year")
  end
end
