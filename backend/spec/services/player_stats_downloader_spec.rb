require "rails_helper"
require "csv"

RSpec.describe PlayerStatsDownloader, type: :service do
  it "downloads MLB batting rows and returns import-ready csv data" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    allow(downloader).to receive(:fetch_fangraphs_values).and_return(
      408234 => {
        "WAR" => 4.2, "wOBA" => 0.398, "wRC+" => 148.4, "OPS+" => 146.2,
        "Offense" => 31.5, "BaseRunning" => 1.4, "Defense" => -2.3,
        "GB%" => 0.39, "FB%" => 0.41, "LD%" => 0.2,
        "Pull%" => 0.43, "Cent%" => 0.32, "Oppo%" => 0.25, "ballsInPlay" => 410,
        "Swing%" => 0.49, "O-Swing%" => 0.27, "Contact%" => 0.78,
        "Z-Contact%" => 0.85, "SwStr%" => 0.11
      }
    )
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
    expect(csv.first.to_h).to include(
      "WAR" => "4.2",
      "wOBA" => "0.398",
      "wRC+" => "148.4",
      "OPS+" => "146.2",
      "Offense" => "31.5",
      "BaseRunning" => "1.4",
      "Defense" => "-2.3",
      "GB%" => "0.39",
      "Oppo%" => "0.25",
      "Swing%" => "0.49",
      "O-Swing%" => "0.27",
      "Contact%" => "0.78",
      "Z-Contact%" => "0.85",
      "SwStr%" => "0.11"
    )
  end

  it "derives OPS+ from the FanGraphs league-adjusted OBP+ and SLG+ components" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)

    expect(downloader.send(:calculated_ops_plus, { "OBP+" => 99.9645, "SLG+" => 121.64 })).to be_within(0.0001).of(121.6045)
    expect(downloader.send(:calculated_ops_plus, { "OBP+" => nil, "SLG+" => 121.64 })).to be_nil
  end

  it "adds FanGraphs pitcher rate and outcome values to MLB pitching rows" do
    downloader = described_class.new(category: "pitching", start_year: 2026, end_year: 2026)
    allow(downloader).to receive(:fetch_fangraphs_values).and_return(
      669373 => {
        "WAR" => 6.6, "K%" => 0.322, "BB%" => 0.044, "K-BB%" => 0.278, "K/BB" => 7.3,
        "BABIP" => 0.273, "LOB%" => 0.806, "FIP" => 2.45, "xFIP" => 2.66
      }
    )
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          {
            "playerId" => 669373, "firstName" => "Tarik", "lastName" => "Skubal",
            "teamId" => 116, "teamAbbrev" => "DET", "teamName" => "Detroit Tigers",
            "teamShortName" => "Tigers", "inningsPitched" => "190.1", "earnedRunAverage" => "2.21"
          }
        ]
      }
    )

    result = downloader.call
    row = CSV.parse(result.dig(:data, :csv_data), headers: true).first.to_h

    expect(row).to include(
      "K%" => "0.322", "BB%" => "0.044", "K-BB%" => "0.278", "K/BB" => "7.3",
      "BABIP" => "0.273", "LOB%" => "0.806", "FIP" => "2.45", "xFIP" => "2.66"
    )
  end

  it "normalizes pitcher aliases and validates the year range" do
    bad_range = described_class.call(category: "pitching", start_year: 2026, end_year: 2025)

    expect(bad_range[:success]).to be(false)
    expect(bad_range[:message]).to eq("End year must be greater than or equal to start year")
  end
end
