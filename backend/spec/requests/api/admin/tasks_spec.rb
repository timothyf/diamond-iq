require "rails_helper"

RSpec.describe "Api::Admin::Tasks", type: :request do
  it "lists the admin tasks exposed through the API" do
    early_schedule = create_schedule(start_date: Date.new(2026, 3, 26), end_date: Date.new(2026, 4, 7))
    late_schedule = create_schedule(start_date: Date.new(2026, 5, 2), end_date: Date.new(2026, 5, 31))
    create_game(schedule: early_schedule, official_date: Date.new(2026, 3, 26))
    create_game(schedule: late_schedule, official_date: Date.new(2026, 9, 22))
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    player = create_player(team: tigers)
    stat_type = create_stat_type
    create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 1901 })
    create_player_season_stat(player: player, stat_type: stat_type, attributes: { season: 2026 })
    PitchDatum.create!(game_pk: 700_001, at_bat_number: 1, pitch_number: 1, game_date: Date.new(2026, 4, 1), raw_data: { "pitch" => 1 })
    PitchDatum.create!(game_pk: 700_002, at_bat_number: 1, pitch_number: 1, game_date: Date.new(2026, 5, 31), raw_data: { "pitch" => 2 })

    get api_admin_tasks_path

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("id")).to contain_exactly(
      "mlb_schedule_sync",
      "mlb_game_details_sync",
      "mlb_player_profiles_sync",
      "mlb_roster_sync",
      "mlb_roster_snapshots_sync",
      "player_positions_backfill"
    )
    expect(json_body.dig("meta", "schedule_date_range")).to eq(
      "earliest_game_date" => "2026-03-26",
      "latest_game_date" => "2026-09-22"
    )
    expect(json_body.dig("meta", "schedule_import_range")).to eq(
      "earliest_import_date" => "2026-03-26",
      "latest_import_date" => "2026-05-31"
    )
    expect(json_body.dig("meta", "mlb_teams")).to eq(
      [
        {
          "id" => tigers.id,
          "mlb_id" => 116,
          "name" => "Detroit Tigers",
          "abbreviation" => "DET",
          "league" => "american"
        }
      ]
    )
    expect(json_body.dig("meta", "database")).to include(
      "environment" => "test",
      "adapter" => "PostgreSQL"
    )
    expect(json_body.dig("meta", "database", "size_bytes")).to be_positive
    expect(json_body.dig("meta", "player_season_stats")).to include(
      "earliest_season" => 1901,
      "latest_season" => 2026
    )
    expect(json_body.dig("meta", "player_season_stats", "approximate_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "pitch_data")).to include(
      "earliest_game_date" => "2026-04-01",
      "latest_game_date" => "2026-05-31"
    )
    expect(json_body.dig("meta", "pitch_data", "approximate_row_count")).to be_a(Integer)
    expect(json_body.dig("meta", "game_details")).to include(
      "synchronized_game_count" => 0,
      "plate_appearance_count" => 0,
      "linked_pitch_count" => 0
    )
  end

  it "returns an empty schedule date range when no games are stored" do
    get api_admin_tasks_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "schedule_date_range")).to eq(
      "earliest_game_date" => nil,
      "latest_game_date" => nil
    )
    expect(json_body.dig("meta", "schedule_import_range")).to eq(
      "earliest_import_date" => nil,
      "latest_import_date" => nil
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
