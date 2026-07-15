require "rails_helper"

RSpec.describe MlbRosterBatchSync do
  it "synchronizes every locally available American League team" do
    described_class::TEAM_IDS_BY_LEAGUE.fetch("american").each do |mlb_id|
      create_team(mlb_id: mlb_id)
    end
    allow(MlbRosterSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized roster",
      data: { membership_count: 2, created_player_count: 1 }
    )

    result = described_class.call(
      scope: "american",
      season: 2026,
      roster_type: "40Man",
      as_of: Date.new(2026, 7, 15)
    )

    expect(result).to include(success: true, message: "Synchronized 15 MLB team rosters")
    expect(result[:data]).to include(
      scope: "american",
      team_count: 15,
      successful_team_count: 15,
      membership_count: 30,
      created_player_count: 15
    )
    expect(MlbRosterSync).to have_received(:call).exactly(15).times
  end

  it "synchronizes one selected team" do
    create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    allow(MlbRosterSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized roster",
      data: { membership_count: 40 }
    )

    result = described_class.call(scope: "team", team_mlb_id: 116)

    expect(result).to include(success: true)
    expect(result[:data]).to include(team_count: 1, team_mlb_ids: [ 116 ], membership_count: 40)
    expect(MlbRosterSync).to have_received(:call).with(
      team_mlb_id: 116,
      season: Date.current.year,
      roster_type: "40Man",
      as_of: Date.current
    )
  end

  it "does not start a batch when a selected team is missing locally" do
    allow(MlbRosterSync).to receive(:call)

    result = described_class.call(scope: "team", team_mlb_id: 116)

    expect(result).to include(success: false)
    expect(result[:data]).to include(missing_team_mlb_ids: [ 116 ])
    expect(MlbRosterSync).not_to have_received(:call)
  end

  it "includes the first team error in a failed batch summary" do
    create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    allow(MlbRosterSync).to receive(:call).and_return(
      success: false,
      message: "MLB roster import validation failed",
      data: { errors: [ "Cannot synchronize before existing snapshot" ] }
    )

    result = described_class.call(scope: "team", team_mlb_id: 116)

    expect(result[:success]).to be(false)
    expect(result[:message]).to eq(
      "Synchronized 0 of 1 MLB team rosters. First failure for MLB team 116: Cannot synchronize before existing snapshot"
    )
  end
end
