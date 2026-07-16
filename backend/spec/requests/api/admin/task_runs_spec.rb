require "rails_helper"

RSpec.describe "Api::Admin::TaskRuns", type: :request do
  include ActiveJob::TestHelper

  it "enqueues a tracked game-detail synchronization with a stored game count" do
    create_game(mlb_id: 810_001, official_date: Date.new(2026, 7, 15))
    create_game(mlb_id: 810_002, official_date: Date.new(2026, 7, 15))

    expect do
      post api_admin_task_runs_path, params: {
        task_name: "mlb_game_details_sync",
        start_date: "2026-07-15",
        end_date: "2026-07-15"
      }
    end.to have_enqueued_job(MlbGameDetailsSyncJob)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include(
      "task_name" => "mlb_game_details_sync",
      "status" => "queued",
      "total_items" => 2,
      "processed_items" => 0,
      "progress_percentage" => 0.0
    )
  end

  it "returns active runs for page-reload recovery and accepts cancellation" do
    completed = AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "completed", total_items: 1, completed_items: 1)
    active = AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "running", total_items: 10, completed_items: 4)

    get api_admin_task_runs_path, params: { task_name: "mlb_game_details_sync", active: true }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to eq([ active.id ])
    expect(json_body.fetch("data").pluck("id")).not_to include(completed.id)

    post cancel_api_admin_task_run_path(active)

    expect(response).to have_http_status(:accepted)
    expect(json_body.fetch("data")).to include("id" => active.id, "cancel_requested" => true, "status" => "running")
  end

  it "shows current progress and rejects invalid ranges" do
    run = AdminTaskRun.create!(
      task_name: "mlb_game_details_sync",
      status: "running",
      total_items: 10,
      completed_items: 4,
      current_item_mlb_id: 810_005,
      current_item_label: "DET at CLE — July 15, 2026",
      started_at: 1.minute.ago
    )

    get api_admin_task_run_path(run)
    expect(json_body.fetch("data")).to include(
      "progress_percentage" => 40.0,
      "current_item_mlb_id" => 810_005,
      "current_item_label" => "DET at CLE — July 15, 2026"
    )

    post api_admin_task_runs_path, params: {
      task_name: "mlb_game_details_sync",
      start_date: "2026-07-16",
      end_date: "2026-07-15"
    }
    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("End date must be on or after start date")
  end

  it "prevents concurrent game-detail synchronizations" do
    AdminTaskRun.create!(task_name: "mlb_game_details_sync", status: "running")

    post api_admin_task_runs_path, params: {
      task_name: "mlb_game_details_sync",
      start_date: "2026-07-15",
      end_date: "2026-07-15"
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("A game detail synchronization is already queued or running")
  end
end
