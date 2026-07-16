require "rails_helper"

RSpec.describe MlbGameDetailsProgressTracker do
  it "does not reset progress when a running task restarts" do
    task_run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 45,
      completed_items: 8,
      failed_items: 1,
      result_data: { "failures" => [{ "mlb_id" => 822_744, "message" => "prior failure" }] },
      started_at: 2.minutes.ago,
      last_heartbeat_at: 10.seconds.ago
    )
    tracker = described_class.new(task_run)

    tracker.start!(total: 45)

    reloaded = task_run.reload
    expect(reloaded.status).to eq("running")
    expect(reloaded.completed_items).to eq(8)
    expect(reloaded.failed_items).to eq(1)
    expect(reloaded.result_data.fetch("failures").size).to eq(1)
    expect(reloaded.started_at).to be_present
  end

  it "preserves existing result_data metadata when starting" do
    task_run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "queued",
      total_items: 0,
      completed_items: 0,
      failed_items: 0,
      result_data: { "active_execution_job_id" => "job-123" }
    )
    tracker = described_class.new(task_run)

    tracker.start!(total: 12)

    expect(task_run.reload.result_data).to include("active_execution_job_id" => "job-123")
  end

  it "updates progress even if the original task run instance has unsaved attributes" do
    task_run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 2,
      completed_items: 0,
      failed_items: 0,
      result_data: {}
    )
    game = create_game(mlb_id: 822_744)
    tracker = described_class.new(task_run)

    # Simulate stale in-memory state that used to break `with_lock` on shared AR objects.
    task_run.current_item_mlb_id = game.mlb_id
    task_run.current_item_label = "stale"

    expect { tracker.game_finished!(game: game, success: true) }.not_to raise_error

    expect(task_run.reload).to have_attributes(completed_items: 1, failed_items: 0)
  end

  it "records failed game details on unsuccessful completion" do
    task_run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 1,
      completed_items: 0,
      failed_items: 0,
      result_data: {}
    )
    game = create_game(mlb_id: 825_013)
    tracker = described_class.new(task_run)

    tracker.game_finished!(game: game, success: false, message: "runtime failure")

    reloaded = task_run.reload
    expect(reloaded.completed_items).to eq(0)
    expect(reloaded.failed_items).to eq(1)
    expect(reloaded.result_data.fetch("failures")).to include(
      a_hash_including("mlb_id" => 825_013, "message" => "runtime failure")
    )
  end

  it "does not increment completed or failed counters once total has been reached" do
    task_run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 2,
      completed_items: 2,
      failed_items: 0,
      result_data: {}
    )
    tracker = described_class.new(task_run)

    tracker.game_finished!(game: create_game(mlb_id: 899_001), success: true)
    tracker.game_finished!(game: create_game(mlb_id: 899_002), success: false, message: "should not count")

    reloaded = task_run.reload
    expect(reloaded.completed_items).to eq(2)
    expect(reloaded.failed_items).to eq(0)
  end
end