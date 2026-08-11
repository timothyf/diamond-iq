require "rails_helper"

RSpec.describe SampleDataBootstrap do
  let(:config) do
    {
      periods: [
        { start_date: "2025-04-01", end_date: "2025-05-31" },
        { start_date: "2026-04-01", end_date: "2026-05-31" }
      ],
      game_types: "R",
      pitch_chunk_days: 7
    }
  end

  it "validates the configured bootstrap plan without importing data in dry-run mode" do
    expect(SeedFu).not_to receive(:seed)

    result = described_class.call(config: config, dry_run: true)

    expect(result).to include(success: true, message: "Sample-data bootstrap plan is valid")
    expect(result.dig(:data, :periods)).to eq([
      { start_date: "2025-04-01", end_date: "2025-05-31" },
      { start_date: "2026-04-01", end_date: "2026-05-31" }
    ])
  end

  it "seeds and synchronizes stats, games, pitches, and profiles for each configured period" do
    allow(SeedFu).to receive(:seed)
    allow(PlayerStatsDownloader).to receive(:call).and_return(success_result(csv_data: "header\n"))
    allow(PlayerStatsImporter).to receive(:call).and_return(success_result(imported_count: 12))
    allow(MlbScheduleSync).to receive(:call).and_return(success_result)
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(success_result(game_count: 4))
    allow(PitchDataBatchSync).to receive(:call).and_return(success_result(imported_count: 55))
    allow(MlbPlayerProfilesSync).to receive(:call).and_return(success_result(profile_count: 8))

    result = described_class.call(config: config, worker_count: 3)

    expect(result[:success]).to be(true)
    expect(PlayerStatsDownloader).to have_received(:call).with(category: "batting", start_year: 2025, end_year: 2026)
    expect(MlbScheduleSync).to have_received(:call).twice
    expect(MlbGameDetailsBatchSync).to have_received(:call).with(
      start_date: Date.new(2025, 4, 1), end_date: Date.new(2025, 5, 31), worker_count: 3
    )
    expect(PitchDataBatchSync).to have_received(:call).twice
    expect(MlbPlayerProfilesSync).to have_received(:call).with(only_missing: true)
  end

  def success_result(data = {})
    { success: true, message: "ok", data: data }
  end
end
