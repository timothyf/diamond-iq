require "rails_helper"

RSpec.describe MlbScheduleSyncJob, type: :job do
  it "runs schedule synchronization through Active Job" do
    result = { success: true, message: "Synchronized", data: { game_count: 1 } }
    allow(MlbScheduleSync).to receive(:call).and_return(result)

    expect(
      described_class.perform_now(start_date: "2026-07-14", end_date: "2026-07-15", game_types: "R")
    ).to eq(result)
    expect(MlbScheduleSync).to have_received(:call).with(
      start_date: "2026-07-14",
      end_date: "2026-07-15",
      game_types: "R",
      sport_id: 1
    )
  end

  it "raises so the queue adapter can retry failures" do
    allow(MlbScheduleSync).to receive(:call).and_return(success: false, message: "HTTP 503", data: {})

    expect do
      described_class.perform_now(start_date: "2026-07-14", end_date: "2026-07-15")
    end.to raise_error(RuntimeError, "MLB schedule synchronization failed: HTTP 503")
  end
end
