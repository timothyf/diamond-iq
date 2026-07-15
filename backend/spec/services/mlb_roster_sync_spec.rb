require "rails_helper"

RSpec.describe MlbRosterSync do
  it "passes downloaded source metadata to the importer" do
    download_result = {
      success: true,
      message: "Downloaded",
      data: {
        payload: { "roster" => [] },
        team_mlb_id: 116,
        season: 2026,
        roster_type: "40Man",
        as_of: "2026-07-14",
        source_url: "https://statsapi.mlb.com/api/v1/teams/116/roster?example=true",
        fetched_at: "2026-07-14T12:00:00Z"
      }
    }
    import_result = { success: true, message: "Synchronized", data: { membership_count: 0 } }
    allow(MlbRosterDownloader).to receive(:call).and_return(download_result)
    allow(MlbRosterImporter).to receive(:call).and_return(import_result)

    result = described_class.call(team_mlb_id: 116, season: 2026, as_of: "2026-07-14")

    expect(result).to eq(import_result)
    expect(MlbRosterImporter).to have_received(:call).with(download_result[:data])
  end

  it "does not import when the download fails" do
    failure = { success: false, message: "Network failed", data: {} }
    allow(MlbRosterDownloader).to receive(:call).and_return(failure)
    expect(MlbRosterImporter).not_to receive(:call)

    expect(described_class.call(team_mlb_id: 116, season: 2026)).to eq(failure)
  end
end
