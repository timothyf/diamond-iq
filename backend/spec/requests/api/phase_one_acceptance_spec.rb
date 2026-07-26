require "rails_helper"

RSpec.describe "Phase 1 acceptance workflows", type: :request do
  let(:season) { Date.current.year }
  let(:tigers) { create_team(name: "Detroit Tigers", abbreviation: "DET", mlb_id: 116) }
  let(:guardians) { create_team(name: "Cleveland Guardians", abbreviation: "CLE", mlb_id: 114) }

  it "compares representative positional peers with season production" do
    second_base = create_position(mlb_code: "4", abbreviation: "2B", name: "Second Base", position_type: "infielder")
    Riley = create_player(team: tigers, attributes: { mlb_id: 682985, first_name: "Riley", last_name: "Greene" })
    Colt = create_player(team: guardians, attributes: { mlb_id: 691006, first_name: "Colt", last_name: "Keith" })
    [ Riley, Colt ].each do |player|
      create_player_position(player: player, position: second_base, attributes: { is_primary: true })
    end
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    [ [ Riley, 24 ], [ Colt, 13 ] ].each do |player, value|
      create_player_season_stat(player: player, stat_type: home_runs, attributes: { season: season, value: value })
    end

    get api_player_path(Riley)
    riley_response = json_body.fetch("data")
    get api_player_path(Colt)
    colt_response = json_body.fetch("data")

    expect(riley_response.dig("positions", "primary", "abbreviation")).to eq("2B")
    expect(colt_response.dig("positions", "primary", "abbreviation")).to eq("2B")
    expect(riley_response.dig("season_overview", "stats")).to include(hash_including("key" => "homeRuns", "value" => "24.0"))
    expect(colt_response.dig("season_overview", "stats")).to include(hash_including("key" => "homeRuns", "value" => "13.0"))
  end

  it "produces an opponent starter report for the next game" do
    pitcher = create_player(
      team: guardians,
      attributes: { mlb_id: 681190, first_name: "Tanner", last_name: "Bibee" }
    )
    schedule = create_schedule(season: season)
    game = create_game(
      schedule: schedule,
      home_team: tigers,
      away_team: guardians,
      official_date: Date.current + 1.day,
      status: "scheduled",
      venue_name: "Comerica Park",
      away_probable_pitcher: pitcher
    )

    post api_team_opponent_reports_path(tigers), params: { season: season }

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "opponent", "abbreviation")).to eq("CLE")
    expect(json_body.dig("data", "snapshot", "series", 0, "id")).to eq(game.id)
    expect(json_body.dig("data", "snapshot", "probable_starters", 0, "player", "full_name")).to eq("Tanner Bibee")
  end

  it "builds and compares multiple legal lineup scenarios" do
    positions = LineupScenarioEntry::DEFENSIVE_POSITIONS.map.with_index do |abbreviation, index|
      create_position(mlb_code: (index + 1).to_s, abbreviation: abbreviation, name: abbreviation)
    end
    players = positions.each_with_index.map do |position, index|
      player = create_player(team: tigers, attributes: { first_name: "Detroit", last_name: "Starter#{index + 1}" })
      create_player_position(player: player, position: position, attributes: { is_primary: true })
      create_team_membership(player: player, team: tigers, starts_on: Date.current - 30.days, roster_status: "active")
      player
    end
    entries = players.each_with_index.map do |player, index|
      { player_id: player.id, batting_slot: index + 1, defensive_position: positions[index].abbreviation }
    end

    [ [ "Opening day defense", entries ], [ "Late-inning defense", entries.rotate(1) ] ].each do |name, scenario_entries|
      post api_team_lineup_scenarios_path(tigers), params: {
        season: season,
        scenario_date: Date.current.iso8601,
        name: name,
        notes: "Representative MLB lineup scenario",
        entries: scenario_entries
      }
      expect(response).to have_http_status(:created)
    end

    get api_team_lineup_scenarios_path(tigers), params: { season: season }

    expect(response).to have_http_status(:ok)
    scenarios = json_body.fetch("data")
    expect(scenarios.map { |scenario| scenario.fetch("name") }).to contain_exactly("Opening day defense", "Late-inning defense")
    expect(scenarios).to all(include("entries" => have_attributes(length: 9)))
  end

  it "creates a watchlist of external players fitting a roster need" do
    external_team = create_team(name: "New York Yankees", abbreviation: "NYY", mlb_id: 147)
    target = create_player(
      team: external_team,
      attributes: { mlb_id: 592206, first_name: "Aaron", last_name: "Judge" }
    )

    post api_watchlists_path, params: { name: "Right-handed power targets", description: "External middle-order options" }
    expect(response).to have_http_status(:created)
    watchlist_id = json_body.dig("data", "id")

    post api_watchlist_watchlist_entries_path(watchlist_id), params: { player_id: target.id }
    expect(response).to have_http_status(:created)
    entry_id = json_body.dig("data", "id")

    patch api_watchlist_entry_path(entry_id), params: {
      priority: "high", status: "active", recommendation: "pursue",
      fit_score: 5, need_score: 5, cost_score: 3, risk_score: 2,
      tags: [ "power", "middle order" ], notes: "Fits Detroit's right-handed power need."
    }
    expect(response).to have_http_status(:ok)

    get api_watchlists_path

    expect(response).to have_http_status(:ok)
    entry = json_body.dig("data", 0, "entries", 0)
    expect(entry.dig("player", "full_name")).to eq("Aaron Judge")
    expect(entry["recommendation"]).to eq("pursue")
    expect(entry["fit_score"]).to eq(5)
  end
end
