require "rails_helper"

RSpec.describe PlayerSeasonStatsTeamVerifier, type: :service do
  class FakeTeamVerifierDownloader
    def self.call(category:, start_year:, end_year:)
      csv_data = <<~CSV
        source_season,season,fetched_at_utc,stat_type,playerId,playerName,playerFirstName,playerLastName,playerUseName,teamId,teamAbbrev,teamName,teamShortName,wins,earnedRunAverage
        #{start_year},#{end_year},2026-06-26T22:07:01Z,#{category == "pitching" ? "pitcher" : "batter"},118787,Denny McLain,Dennis,McLain,Denny,116,DET,Detroit Tigers,Tigers,31,1.96
      CSV

      {
        success: true,
        message: "Downloaded fake rows",
        data: {
          csv_data: csv_data
        }
      }
    end
  end

  it "reports season team mismatches without updating rows by default" do
    atlanta = create_team(mlb_id: 144, name: "Atlanta Braves", abbreviation: "ATL", team_name: "Braves", short_name: "Braves")
    detroit = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET", team_name: "Tigers", short_name: "Tigers")
    pitcher = create_player(team: atlanta, attributes: { mlb_id: 118787, first_name: "Denny", last_name: "McLain" })
    wins = create_stat_type(name: "W", label: "W", category: "pitching")
    era = create_stat_type(name: "ERA", label: "ERA", category: "pitching")
    wins_row = create_player_season_stat(player: pitcher, stat_type: wins, attributes: { team: atlanta, season: 1968, value: 31 })
    era_row = create_player_season_stat(player: pitcher, stat_type: era, attributes: { team: atlanta, season: 1968, value: 1.96 })

    result = described_class.call(category: "pitching", start_year: 1968, end_year: 1968, downloader: FakeTeamVerifierDownloader)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :checked_groups)).to eq(1)
    expect(result.dig(:data, :mismatched_groups)).to eq(1)
    expect(result.dig(:data, :mismatched_rows)).to eq(2)
    expect(result.dig(:data, :updated_rows)).to eq(0)
    expect(result.dig(:data, :samples, 0)).to include(
      player: "Denny McLain",
      season: 1968,
      expected_team: "DET",
      expected_team_mlb_id: 116,
      stored_team_mlb_ids: [144],
      row_count: 2
    )
    expect(wins_row.reload.team).to eq(atlanta)
    expect(era_row.reload.team).to eq(atlanta)
    expect(detroit.reload.abbreviation).to eq("DET")
  end

  it "repairs mismatched season team ids when fix is enabled" do
    atlanta = create_team(mlb_id: 144, name: "Atlanta Braves", abbreviation: "ATL", team_name: "Braves", short_name: "Braves")
    detroit = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET", team_name: "Tigers", short_name: "Tigers")
    pitcher = create_player(team: atlanta, attributes: { mlb_id: 118787, first_name: "Denny", last_name: "McLain" })
    wins = create_stat_type(name: "W", label: "W", category: "pitching")
    row = create_player_season_stat(player: pitcher, stat_type: wins, attributes: { team: atlanta, season: 1968, value: 31 })

    result = described_class.call(category: "pitching", start_year: 1968, end_year: 1968, fix: true, downloader: FakeTeamVerifierDownloader)

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :mismatched_groups)).to eq(1)
    expect(result.dig(:data, :updated_rows)).to eq(1)
    expect(row.reload.team).to eq(detroit)
  end
end
