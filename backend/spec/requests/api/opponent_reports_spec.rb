require "rails_helper"

RSpec.describe "Api::OpponentReports", type: :request do
  let(:owner) { create_user(role: "scout") }
  let(:headers) { user_headers(owner) }

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

    post api_team_opponent_reports_path(team), params: { season: Date.current.year }, headers: headers

    expect(response).to have_http_status(:created)
    report_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "owner", "id")).to eq(owner.id)
    expect(json_body.dig("data", "opponent", "id")).to eq(opponent.id)
    expect(json_body.dig("data", "snapshot", "series", 0, "id")).to eq(game.id)
    expect(json_body.dig("data", "snapshot", "probable_starters", 0, "player", "id")).to eq(pitcher.id)

    get api_team_opponent_reports_path(team), headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to contain_exactly(
      hash_including("id" => report_id, "probable_starter_count" => 1)
    )

    get api_opponent_report_path(report_id), headers: headers

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "title")).to include("DET vs CLE")
    expect(json_body.dig("data", "snapshot", "generated_at")).to be_present

    patch api_opponent_report_path(report_id), params: { title: "Updated Cleveland advance report" }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "title")).to eq("Updated Cleveland advance report")

    get audit_history_api_opponent_report_path(report_id), headers: headers
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").pluck("action")).to eq(%w[updated created])
    expect(json_body.dig("data", 0, "user", "id")).to eq(owner.id)
  end

  it "rejects generation when no upcoming series exists" do
    team = create_team

    post api_team_opponent_reports_path(team), params: { season: Date.current.year }, headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("message")).to eq("No upcoming opponent is available for this season.")
  end

  it "requires authentication and isolates reports by owner while allowing administrator oversight" do
    team = create_team
    opponent = create_team
    report = OpponentReport.create!(
      team: team,
      opponent_team: opponent,
      owner: owner,
      season: Date.current.year,
      series_starts_on: Date.current,
      series_ends_on: Date.current + 2.days,
      title: "Private advance report",
      generated_at: Time.current
    )

    get api_opponent_report_path(report)
    expect(response).to have_http_status(:unauthorized)

    other_user = create_user(role: "analyst")
    get api_team_opponent_reports_path(team), headers: user_headers(other_user)
    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to be_empty

    get api_opponent_report_path(report), headers: user_headers(other_user)
    expect(response).to have_http_status(:forbidden)

    patch api_opponent_report_path(report), params: { title: "Unauthorized change" }, headers: user_headers(other_user)
    expect(response).to have_http_status(:forbidden)
    expect(report.reload.title).to eq("Private advance report")

    admin = create_user(role: "administrator")
    get api_opponent_report_path(report), headers: user_headers(admin)
    expect(response).to have_http_status(:ok)
  end

  it "does not allow viewers to generate reports" do
    team = create_team
    viewer = create_user(role: "viewer")

    post api_team_opponent_reports_path(team), params: { season: Date.current.year }, headers: user_headers(viewer)

    expect(response).to have_http_status(:forbidden)
    expect(OpponentReport.count).to eq(0)
  end
end
