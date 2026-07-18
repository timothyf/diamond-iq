require "rails_helper"

RSpec.describe "Api::Home", type: :request do
  it "uses the Eastern calendar date during the UTC rollover window" do
    allow(Time).to receive(:current).and_return(Time.utc(2026, 7, 18, 3, 22))
    tigers = create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET")
    guardians = create_team(mlb_id: 114, name: "Cleveland Guardians", abbreviation: "CLE")
    schedule = create_schedule(
      season: 2026,
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27)
    )
    eastern_today = create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 17),
      scheduled_at: Time.utc(2026, 7, 17, 23, 10),
      home_team: tigers,
      away_team: guardians
    )
    create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 18),
      scheduled_at: Time.utc(2026, 7, 18, 23, 10),
      home_team: guardians,
      away_team: tigers
    )

    get api_home_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "as_of")).to eq("2026-07-17")
    expect(json_body.dig("data", "games").pluck("id")).to eq([ eastern_today.id ])
  end

  it "returns the daily slate, qualified leaders, team pulse, and freshness metadata" do
    tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    schedule = create_schedule(
      season: 2026,
      schedule_type: "R",
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27)
    )
    hitter = create_player(team: tigers, attributes: { mlb_id: 682_985, first_name: "Riley", last_name: "Greene" })
    pitcher = create_player(team: guardians, attributes: { mlb_id: 676_440, first_name: "Tanner", last_name: "Bibee" })

    game = create_game(
      schedule: schedule,
      official_date: Date.new(2026, 7, 16),
      scheduled_at: Time.zone.parse("2026-07-16T17:10:00Z"),
      status: "final",
      detailed_status: "Final",
      home_team: tigers,
      away_team: guardians,
      home_score: 5,
      away_score: 3,
      last_synced_at: Time.zone.parse("2026-07-16T20:30:00Z"),
      details_last_synced_at: Time.zone.parse("2026-07-16T20:31:00Z")
    )

    stat_types = {
      at_bats: create_stat_type(name: "atBats", label: "AB", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting"),
      home_runs: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      innings: create_stat_type(name: "inningsPitched", label: "IP", category: "pitching"),
      era: create_stat_type(name: "ERA", label: "ERA", category: "pitching"),
      strikeouts: create_stat_type(name: "strikeOuts", label: "SO", category: "pitching")
    }
    {
      at_bats: 10,
      ops: 1.050,
      home_runs: 3
    }.each do |key, value|
      create_player_season_stat(player: hitter, stat_type: stat_types.fetch(key), attributes: { team: tigers, season: 2026, value: value })
    end
    {
      innings: 5.0,
      era: 1.80,
      strikeouts: 9
    }.each do |key, value|
      create_player_season_stat(player: pitcher, stat_type: stat_types.fetch(key), attributes: { team: guardians, season: 2026, value: value })
    end

    calculated_at = Time.zone.parse("2026-07-16T20:32:00Z")
    TeamDailyMetric.create!(
      team: tigers,
      metric_date: Date.new(2026, 7, 16),
      source_start_date: Date.new(2026, 7, 16),
      source_end_date: Date.new(2026, 7, 16),
      sample_size: 1,
      calculation_version: "v1",
      calculated_at: calculated_at,
      source_name: "DiamondIQ daily analytics",
      metrics: { games: 1, wins: 1, losses: 0, runs_scored: 5, runs_allowed: 3 }
    )
    TeamDailyMetric.create!(
      team: guardians,
      metric_date: Date.new(2026, 7, 16),
      source_start_date: Date.new(2026, 7, 16),
      source_end_date: Date.new(2026, 7, 16),
      sample_size: 1,
      calculation_version: "v1",
      calculated_at: calculated_at,
      source_name: "DiamondIQ daily analytics",
      metrics: { games: 1, wins: 0, losses: 1, runs_scored: 3, runs_allowed: 5 }
    )

    get api_home_path, params: { date: "2026-07-16" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "season")).to eq(2026)
    expect(json_body.dig("data", "games", 0, "id")).to eq(game.id)
    expect(json_body.dig("data", "leaders").map { |leader| leader.fetch("key") }).to eq(%w[ops homeRuns ERA strikeOuts])
    expect(json_body.dig("data", "leaders", 0, "entries", 0, "player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "leaders", 2, "entries", 0, "player", "full_name")).to eq("Tanner Bibee")
    expect(json_body.dig("data", "team_pulse", "best_records", 0, "team", "abbreviation")).to eq("DET")
    expect(json_body.dig("data", "team_pulse", "run_differential", 0, "run_differential")).to eq(2)
    expect(json_body.dig("data", "freshness", "analytics")).to eq("2026-07-16T20:32:00.000Z")
  end
end
