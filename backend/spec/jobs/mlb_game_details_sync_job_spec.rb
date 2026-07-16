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

  it "marks a tracked synchronization failed when the batch returns failure" do
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

    described_class.perform_now(run.id)

    expect(run.reload).to have_attributes(status: "failed", error_message: "MLB feed unavailable", finished_at: be_present)
  end

  it "no-ops when a terminal task is executed again" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "completed",
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-15" },
      total_items: 2,
      completed_items: 2,
      failed_items: 0,
      result_data: { "synchronized_game_count" => 2 },
      finished_at: Time.current
    )
    allow(MlbGameDetailsBatchSync).to receive(:call)

    result = described_class.perform_now(run.id)

    expect(result).to include(success: true, message: "Task already finished")
    expect(MlbGameDetailsBatchSync).not_to have_received(:call)
  end

  it "no-ops when another execution is already in progress" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-15" },
      total_items: 45,
      completed_items: 8,
      failed_items: 0,
      result_data: { "active_execution_job_id" => "other-job-id" },
      last_heartbeat_at: Time.current
    )
    allow(MlbGameDetailsBatchSync).to receive(:call)

    result = described_class.perform_now(run.id)

    expect(result[:success]).to be(true)
    expect(result[:message]).to eq("Task execution already in progress")
    expect(run.reload.status).to eq("running")
    expect(MlbGameDetailsBatchSync).not_to have_received(:call)
  end

  it "completes with deferred analytics refresh when replay starts after all games were already processed" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      task_parameters: { "start_date" => "2026-07-15", "end_date" => "2026-07-15" },
      total_items: 26,
      completed_items: 26,
      failed_items: 0,
      result_data: { "active_execution_job_id" => "6c9c68a6-b53d-4c8d-b4c2-fd0001320a17" },
      started_at: 5.minutes.ago,
      last_heartbeat_at: 5.seconds.ago
    )
    allow(MlbGameDetailsBatchSync).to receive(:call)
    allow_any_instance_of(described_class).to receive(:claim_execution).and_return(:claimed)

    result = described_class.perform_now(run.id)

    expect(result[:success]).to be(true)
    expect(result[:message]).to include("analytics refresh deferred")
    reloaded = run.reload
    expect(reloaded.status).to eq("completed")
    expect(reloaded.result_data.dig("analytics_refresh", "deferred")).to be(true)
    expect(reloaded.result_data["active_execution_job_id"]).to be_nil
    expect(MlbGameDetailsBatchSync).not_to have_received(:call)
  end
end
