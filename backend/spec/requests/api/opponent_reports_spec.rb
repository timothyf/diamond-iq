require "rails_helper"

RSpec.describe "Api::OpponentReports", type: :request do
  it "generates, lists, and returns a saved preparation snapshot" do
    team = create_team(name: "Detroit Tigers", abbreviation: "DET")
    opponent = create_team(name: "Cleveland Guardians", abbreviation: "CLE")
    pitcher = create_player(
      team: opponent,
      attributes: { mlb_id: 999_101, first_name: "Test", last_name: "Starter" }
    )
    schedule = create_schedule(season: Date.current.year)
    game = create_game(
      schedule: schedule,
      home_team: team,
      away_team: opponent,
      official_date: Date.current + 1.day,
      status: "scheduled",
      venue_name: "Comerica Park",
      away_probable_pitcher: pitcher
    )

    post api_team_opponent_reports_path(team), params: { season: Date.current.year }

    expect(response).to have_http_status(:created)
    report_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "opponent", "id")).to eq(opponent.id)
    expect(json_body.dig("data", "snapshot", "series", 0, "id")).to eq(game.id)
    expect(json_body.dig("data", "snapshot", "probable_starters", 0, "player", "id")).to eq(pitcher.id)

    get api_team_opponent_reports_path(team)

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to contain_exactly(
      hash_including("id" => report_id, "probable_starter_count" => 1)
    )

    get api_opponent_report_path(report_id)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "title")).to include("DET vs CLE")
    expect(json_body.dig("data", "snapshot", "generated_at")).to be_present
  end

  it "rejects generation when no upcoming series exists" do
    team = create_team

    post api_team_opponent_reports_path(team), params: { season: Date.current.year }

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("No upcoming opponent is available for this season.")
  end
end
