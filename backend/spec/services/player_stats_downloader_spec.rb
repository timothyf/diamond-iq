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
    allow(downloader).to receive(:fetch_fangraphs_fielding_values).and_return(
      408234 => { "DRS" => -4.0 }
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
      "DRS" => "-4.0",
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
        "BABIP" => 0.273, "LOB%" => 0.806, "ERA-" => 54, "FIP" => 2.45,
        "FIP-" => 58, "xFIP" => 2.66, "xFIP-" => 63, "SIERA" => 2.71, "xERA" => 2.70,
        "RA9-Wins" => 7.1, "WPA" => 4.0, "WPA/LI" => 5.2, "RE24" => 43.6,
        "Clutch" => -1.0, "RAR" => 59.1, "pLI" => 0.95, "SD" => 2, "MD" => 1
      }
    )
    allow(downloader).to receive(:fetch_statcast_values).and_return(
      669373 => { "wOBAAllowed" => 0.246, "xwOBAAllowed" => 0.266 }
    )
    allow(downloader).to receive(:fetch_statcast_run_values).and_return(
      669373 => { "PitchingRuns" => 51.4 }
    )
    allow(downloader).to receive(:fetch_baseball_reference_values).and_return(
      2026 => { 669373 => { "RAA" => 19.3 } }
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
      "BABIP" => "0.273", "LOB%" => "0.806", "ERA-" => "54", "FIP" => "2.45",
      "FIP-" => "58", "xFIP" => "2.66", "xFIP-" => "63", "SIERA" => "2.71",
      "xERA" => "2.7", "wOBAAllowed" => "0.246", "xwOBAAllowed" => "0.266",
      "RA9-Wins" => "7.1", "WPA" => "4.0", "WPA/LI" => "5.2", "RE24" => "43.6",
      "Clutch" => "-1.0", "RAR" => "59.1", "RAA" => "19.3", "PitchingRuns" => "51.4",
      "pLI" => "0.95", "SD" => "2", "MD" => "1"
    )
  end

  it "parses Statcast pitcher wOBA allowed values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2025)
    csv_body = "\uFEFF" + <<~CSV
      "last_name, first_name","player_id","year","player_id","player_name","woba","xwoba"
      "Skubal, Tarik",669373,2025,669373,"Skubal, Tarik",".246",".266"
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body.b)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow_any_instance_of(Net::HTTP).to receive(:request).and_return(response)

    expect(downloader.send(:fetch_statcast_values, 2025)).to eq(
      669373 => { "wOBAAllowed" => 0.246, "xwOBAAllowed" => 0.266 }
    )
  end

  it "parses Baseball-Reference pitcher runs above average values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2026)
    csv_body = <<~CSV
      name_common,mlb_ID,year_ID,runs_above_avg
      Tarik Skubal,669373,2025,42.455
      Tarik Skubal,669373,2026,19.317
      Old Season,123456,2024,10.0
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_baseball_reference_values)).to eq(
      2025 => { 669373 => { "RAA" => 42.455 } },
      2026 => { 669373 => { "RAA" => 19.317 } }
    )
  end

  it "parses Statcast pitcher run values" do
    downloader = described_class.new(category: "pitching", start_year: 2025, end_year: 2025)
    csv_body = "\uFEFF" + <<~CSV
      "year","last_name, first_name","player_id","runs_all"
      "2025","Skubal, Tarik","669373",51.4083
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body.b)
    allow(downloader).to receive(:request_csv).and_return(response)

    expect(downloader.send(:fetch_statcast_run_values, 2025)).to eq(
      669373 => { "PitchingRuns" => 51.4083 }
    )
  end

  it "sums FanGraphs DRS across a player's fielding positions" do
    downloader = described_class.new(category: "batting", start_year: 2026, end_year: 2026)
    response = instance_double(
      Net::HTTPSuccess,
      body: {
        "data" => [
          { "xMLBAMID" => 701678, "Pos" => "SS", "DRS" => 0 },
          { "xMLBAMID" => 701678, "Pos" => "3B", "DRS" => -1 },
          { "xMLBAMID" => 701678, "Pos" => "2B", "DRS" => -3 },
          { "xMLBAMID" => 682985, "Pos" => "CF", "DRS" => 4 }
        ]
      }.to_json
    )
    http = instance_double(Net::HTTP)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(response)

    expect(downloader.send(:fetch_fangraphs_fielding_values, 2026)).to eq(
      701678 => { "DRS" => -4.0 },
      682985 => { "DRS" => 4.0 }
    )
  end

  it "parses Baseball Savant OAA values using the yearly fielder leaderboard" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)

    csv_body = <<~CSV
      player_name,playerId,outs_above_average
      Riley Greene,682985,3
      Jacob Misiorowski,669373,-1.5
    CSV
    response = instance_double(Net::HTTPSuccess, body: csv_body)
    allow(downloader).to receive(:request_csv) do |uri|
      expect(uri.query).to include("startYear=2025", "endYear=2025", "range=year", "csv=true")
      response
    end

    expect(downloader.send(:fetch_statcast_fielding_values, 2025)).to eq(
      682985 => { "OAA" => 3.0 },
      669373 => { "OAA" => -1.5 }
    )
  end

  it "calculates fielding percentage from MLB fielding chances and errors" do
    downloader = described_class.new(category: "batting", start_year: 2025, end_year: 2025)
    allow(downloader).to receive(:fetch_json).and_return(
      {
        "stats" => [
          { "playerId" => 682985, "chances" => 120, "errors" => 2 },
          { "playerId" => 682985, "chances" => 10, "errors" => 0 }
        ]
      },
      { "stats" => [] }
    )

    expect(downloader.send(:fetch_mlb_fielding_values, 2025)).to eq(
      682985 => { "fieldingPercentage" => (128.0 / 130) }
    )
  end

  it "normalizes pitcher aliases and validates the year range" do
    bad_range = described_class.call(category: "pitching", start_year: 2026, end_year: 2025)

    expect(bad_range[:success]).to be(false)
    expect(bad_range[:message]).to eq("End year must be greater than or equal to start year")
  end
end
