require "rails_helper"

RSpec.describe "Api::Admin::Tasks", type: :request do
  it "lists the admin tasks exposed through the API" do
    get api_admin_tasks_path

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to contain_exactly(
      "mlb_schedule_sync",
      "mlb_player_profiles_sync",
      "mlb_roster_sync",
      "player_positions_backfill"
    )
  end

  it "runs an allowlisted admin task and returns its summary" do
    allow(AdminTaskRunner).to receive(:call).and_return(
      success: true,
      task: "mlb_schedule_sync",
      message: "Synchronized 12 MLB games",
      data: { created_game_count: 12 }
    )

    post run_api_admin_task_path("mlb_schedule_sync"),
         params: { start_date: "2026-07-15", end_date: "2026-07-17" }

    expect(response).to have_http_status(:created)
    expect(json_body).to include(
      "task" => "mlb_schedule_sync",
      "success" => true,
      "message" => "Synchronized 12 MLB games"
    )
    expect(AdminTaskRunner).to have_received(:call).with(
      task_name: "mlb_schedule_sync",
      params: instance_of(ActionController::Parameters)
    )
  end

  it "requires the configured admin token for task execution" do
    ENV["ADMIN_API_TOKEN"] = "secret-token"

    post run_api_admin_task_path("player_positions_backfill")

    expect(response).to have_http_status(:unauthorized)
    expect(json_body.fetch("message")).to eq("Admin API token is required")
  end

  it "returns validation failures without starting a task" do
    allow(AdminTaskRunner).to receive(:call).and_return(
      success: false,
      task: "mlb_schedule_sync",
      message: "Start date is required",
      data: { errors: [ "Start date is required" ] }
    )

    post run_api_admin_task_path("mlb_schedule_sync")

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("Start date is required")
  end
end
