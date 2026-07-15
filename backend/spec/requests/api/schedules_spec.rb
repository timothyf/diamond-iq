require "rails_helper"

RSpec.describe "Api::Schedules", type: :request do
  it "returns source metadata and a filtered, paginated game collection" do
    schedule = create_schedule(
      season: 2026,
      schedule_type: "R",
      source_key: "mlb:schedule:1:2026:R",
      source_url: "https://statsapi.mlb.com/api/v1/schedule?season=2026",
      last_synced_at: Time.zone.parse("2026-07-14T12:00:00Z")
    )
    tigers = create_team(mlb_id: 116, abbreviation: "DET")
    guardians = create_team(mlb_id: 114, abbreviation: "CLE")
    matching_game = create_game(
      schedule: schedule,
      home_team: tigers,
      away_team: guardians,
      official_date: Date.new(2026, 7, 14),
      status: "preview",
      game_type: "R"
    )
    create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 15),
      status: "final",
      game_type: "R"
    )

    get api_schedule_path(schedule),
        params: { team_id: tigers.id, status: "preview", page: 1, per_page: 1 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "source_key")).to eq("mlb:schedule:1:2026:R")
    expect(json_body.dig("data", "source_url")).to include("season=2026")
    expect(json_body.dig("data", "last_synced_at")).to eq("2026-07-14T12:00:00.000Z")
    expect(json_body.dig("data", "games", 0, "id")).to eq(matching_game.id)
    expect(json_body.dig("data", "games", 0)).not_to have_key("schedule")
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "per_page")).to eq(1)
  end
end
