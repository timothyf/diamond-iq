require "rails_helper"

RSpec.describe PitchDataSyncJob, type: :job do
  it "records its execution claim while running and clears it after completion" do
    run = AdminTaskRun.create!(
      task_name: "pitch_data_sync",
      task_parameters: {
        "start_date" => "2026-07-18",
        "end_date" => "2026-07-18",
        "game_types" => "R",
        "chunk_days" => 1
      },
      total_items: 1
    )

    allow(PitchDataBatchSync).to receive(:call) do |progress_tracker:, **|
      progress_tracker.start!(total: 1)
      expect(run.reload.result_data["active_execution_job_id"]).to be_present
      { success: true, message: "Synchronized pitch data", data: { imported_count: 10 } }
    end

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "completed", finished_at: be_present)
    expect(run.result_data).to include("imported_count" => 10)
    expect(run.result_data["active_execution_job_id"]).to be_nil
  end
end
