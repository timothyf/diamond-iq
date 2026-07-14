require "rails_helper"

RSpec.describe MlbScheduleSync do
  it "passes downloaded source metadata to the importer" do
    download_result = {
      success: true,
      message: "Downloaded",
      data: {
        payload: { "dates" => [] },
        start_date: "2026-07-14",
        end_date: "2026-07-15",
        game_types: [ "R" ],
        sport_id: 1,
        source_url: "https://statsapi.mlb.com/api/v1/schedule?example=true",
        fetched_at: "2026-07-14T12:00:00Z"
      }
    }
    import_result = { success: true, message: "Synchronized", data: { game_count: 0 } }
    allow(MlbScheduleDownloader).to receive(:call).and_return(download_result)
    allow(MlbScheduleImporter).to receive(:call).and_return(import_result)

    result = described_class.call(start_date: "2026-07-14", end_date: "2026-07-15")

    expect(result).to eq(import_result)
    expect(MlbScheduleImporter).to have_received(:call).with(download_result[:data])
  end

  it "does not import when the download fails" do
    failure = { success: false, message: "Network failed", data: {} }
    allow(MlbScheduleDownloader).to receive(:call).and_return(failure)
    expect(MlbScheduleImporter).not_to receive(:call)

    expect(described_class.call(start_date: "2026-07-14", end_date: "2026-07-15")).to eq(failure)
  end
end
