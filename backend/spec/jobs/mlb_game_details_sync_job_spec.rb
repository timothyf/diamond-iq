require "rails_helper"

RSpec.describe MlbGameDetailsSyncJob, type: :job do
  include ActiveJob::TestHelper

  it "marks a tracked synchronization complete" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-15" },
      total_items: 2
    )
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: true,
      message: "Synchronized details for 2 of 2 MLB games",
      data: { game_count: 2, synchronized_game_count: 2, failed_game_count: 0, cancelled: false }
    )

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "completed", finished_at: be_present)
    expect(run.result_data).to include("synchronized_game_count" => 2)
    expect(MlbGameDetailsBatchSync).to have_received(:call).with(
      start_date: "2026-07-15",
      end_date: "2026-07-15",
      progress_tracker: instance_of(MlbGameDetailsProgressTracker)
    )
  end

  it "retries a failed batch while retaining the tracked task" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      task_parameters: { "mlb_game_id" => 823_443 },
      total_items: 1
    )
    allow(MlbGameDetailsBatchSync).to receive(:call).and_return(
      success: false,
      message: "MLB feed unavailable",
      data: { errors: [] }
    )

    expect { described_class.perform_now(run.id) }.to have_enqueued_job(described_class).with(run.id)
    expect(run.reload.status).to eq("queued")
  end
end
