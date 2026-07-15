require "rails_helper"

RSpec.describe MlbGameDetailsSyncJob, type: :job do
  it "runs the repeatable batch synchronizer" do
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized details for 2 of 2 MLB games",
      data: { synchronized_game_count: 2 }
    )

    described_class.perform_now(start_date: "2026-07-15", end_date: "2026-07-16")

    expect(MlbGameDetailsBatchSync).to have_received(:call).with(
      start_date: "2026-07-15",
      end_date: "2026-07-16",
      mlb_game_id: nil
    )
  end

  it "raises when the synchronization fails so the job adapter can retry" do
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: false,
      message: "MLB feed unavailable",
      data: { errors: [] }
    )

    expect { described_class.perform_now(mlb_game_id: 823_443) }.to raise_error(RuntimeError, "MLB feed unavailable")
  end
end
