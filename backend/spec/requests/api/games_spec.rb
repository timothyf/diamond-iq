require "rails_helper"

RSpec.describe "Api::Games", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    @guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    @schedule = create_schedule(
      season: 2026,
      schedule_type: "R",
      start_date: Date.new(2026, 3, 25),
      end_date: Date.new(2026, 9, 27),
      source_key: "mlb:schedule:1:2026:R",
      last_synced_at: Time.zone.parse("2026-07-14T12:00:00Z")
    )
    @skubal = create_player(
      team: @tigers,
      attributes: { mlb_id: 669_373, first_name: "Tarik", last_name: "Skubal" }
    )
    @bibee = create_player(
      team: @guardians,
      attributes: { mlb_id: 676_440, first_name: "Tanner", last_name: "Bibee" }
    )
    @game = create_game(
      schedule: @schedule,
      mlb_id: 823_443,
      official_date: Date.new(2026, 7, 14),
      scheduled_at: Time.zone.parse("2026-07-14T18:10:00Z"),
      game_type: "R",
      status: "preview",
      detailed_status: "Pre-Game",
      home_team: @tigers,
      away_team: @guardians,
      home_probable_pitcher: @skubal,
      away_probable_pitcher: @bibee,
      venue_name: "Comerica Park",
      source_name: "MLB Stats API",
      source_url: "https://statsapi.mlb.com/api/v1.1/game/823443/feed/live",
      last_synced_at: Time.zone.parse("2026-07-14T12:00:00Z")
    )
  end

  it "returns filtered, paginated games" do
    create_game(
      schedule: @schedule,
      official_date: Date.new(2026, 7, 20),
      status: "final",
      game_type: "R"
    )

    get api_games_path,
        params: {
          team_id: @tigers.id,
          start_date: "2026-07-14",
          end_date: "2026-07-14",
          season: 2026,
          status: "preview",
          game_type: "R"
        }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters", "team_id")).to eq(@tigers.id)
    expect(json_body.dig("meta", "filters", "start_date")).to eq("2026-07-14")
    expect(json_body.fetch("data").map { |game| game.fetch("mlb_id") }).to eq([ 823_443 ])
  end

  it "returns game details with teams, probable pitchers, source metadata, and schedule" do
    get api_game_path(@game)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "home_team", "abbreviation")).to eq("DET")
    expect(json_body.dig("data", "away_team", "abbreviation")).to eq("CLE")
    expect(json_body.dig("data", "home_probable_pitcher", "full_name")).to eq("Tarik Skubal")
    expect(json_body.dig("data", "away_probable_pitcher", "full_name")).to eq("Tanner Bibee")
    expect(json_body.dig("data", "source_name")).to eq("MLB Stats API")
    expect(json_body.dig("data", "source_url")).to include("823443")
    expect(json_body.dig("data", "last_synced_at")).to eq("2026-07-14T12:00:00.000Z")
    expect(json_body.dig("data", "schedule", "source_key")).to eq("mlb:schedule:1:2026:R")
  end

  it "returns normalized box-score and plate-appearance drill-down data" do
    @game.update!(
      details_source_url: "https://statsapi.mlb.com/api/v1.1/game/823443/feed/live",
      details_last_synced_at: Time.zone.parse("2026-07-14T23:00:00Z"),
      home_score: 3,
      away_score: 1,
      live_feed_raw_data: {
        "liveData" => {
          "linescore" => {
            "currentInning" => 9,
            "currentInningOrdinal" => "9th",
            "inningState" => "End",
            "innings" => [
              { "num" => 1, "ordinalNum" => "1st", "away" => { "runs" => 1 }, "home" => { "runs" => 0 } },
              { "num" => 2, "ordinalNum" => "2nd", "away" => { "runs" => 0 }, "home" => { "runs" => 3 } }
            ],
            "teams" => {
              "away" => { "runs" => 1, "hits" => 5, "errors" => 0, "leftOnBase" => 6 },
              "home" => { "runs" => 3, "hits" => 8, "errors" => 1, "leftOnBase" => 7 }
            }
          }
        }
      }
    )
    GamePlayerBattingLine.create!(
      game: @game,
      player: @skubal,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: true,
      batting_order: 900,
      at_bats: 3,
      hits: 1,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "seasonStats" => { "batting" => { "avg" => ".287", "ops" => ".842" } } }
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: @skubal,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: true,
      appearance_order: 1,
      innings_pitched: "7.0",
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "seasonStats" => { "pitching" => { "era" => "2.01", "whip" => "0.99" } } }
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: @bibee,
      team: @guardians,
      opponent_team: @tigers,
      home: false,
      starter: true,
      appearance_order: 1,
      innings_pitched: "6.0",
      decision: "(L, 7-5)",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    @game.game_player_pitching_lines.find_by!(player: @skubal).update!(decision: "(W, 11-2)")
    reliever = create_player(
      team: @tigers,
      attributes: { mlb_id: 700_111, first_name: "Will", last_name: "Vest" }
    )
    GamePlayerPitchingLine.create!(
      game: @game,
      player: reliever,
      team: @tigers,
      opponent_team: @guardians,
      home: true,
      starter: false,
      appearance_order: 2,
      innings_pitched: "1.0",
      decision: "(S, 1)",
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    appearance = PlateAppearance.create!(
      game: @game,
      batter: @skubal,
      pitcher: @bibee,
      batting_team: @tigers,
      fielding_team: @guardians,
      at_bat_index: 0,
      plate_appearance_number: 1,
      inning: 1,
      half_inning: "bottom",
      event: "Single",
      event_type: "single",
      complete: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current,
      raw_data: { "matchup" => { "splits" => { "menOnBase" => "RISP" } } }
    )
    PitchDatum.create!(
      game: @game,
      plate_appearance: appearance,
      game_pk: @game.mlb_id,
      at_bat_number: 1,
      pitch_number: 1,
      pitch_type: "FF",
      release_speed: 96.4,
      raw_data: { "pitch_type" => "FF" }
    )

    get api_game_path(@game)

    expect(json_body.dig("data", "details")).to include(
      "synchronized" => true,
      "last_synced_at" => "2026-07-14T23:00:00.000Z"
    )
    expect(json_body.dig("data", "details", "line_score", "innings")).to eq(
      [
        {
          "number" => 1,
          "ordinal" => "1st",
          "away" => { "runs" => 1, "hits" => nil, "errors" => nil, "left_on_base" => nil },
          "home" => { "runs" => 0, "hits" => nil, "errors" => nil, "left_on_base" => nil }
        },
        {
          "number" => 2,
          "ordinal" => "2nd",
          "away" => { "runs" => 0, "hits" => nil, "errors" => nil, "left_on_base" => nil },
          "home" => { "runs" => 3, "hits" => nil, "errors" => nil, "left_on_base" => nil }
        }
      ]
    )
    expect(json_body.dig("data", "details", "line_score", "totals", "home")).to eq(
      "runs" => 3,
      "hits" => 8,
      "errors" => 1,
      "left_on_base" => 7
    )
    expect(json_body.dig("data", "details", "batting_lines", 0, "player", "full_name")).to eq("Tarik Skubal")
    expect(json_body.dig("data", "details", "batting_lines", 0)).to include(
      "batting_average" => "0.287",
      "ops" => "0.842"
    )
    expect(json_body.dig("data", "details", "pitching_lines", 0)).to include(
      "decision" => "(L, 7-5)"
    )
    expect(json_body.dig("data", "details", "pitching_lines", 1)).to include(
      "era" => "2.01",
      "whip" => "0.99",
      "decision" => "(W, 11-2)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "winning_pitcher")).to include(
      "player" => include("full_name" => "Tarik Skubal"),
      "decision" => "(W, 11-2)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "losing_pitcher")).to include(
      "player" => include("full_name" => "Tanner Bibee"),
      "decision" => "(L, 7-5)"
    )
    expect(json_body.dig("data", "details", "insights", "decisions", "save")).to include(
      "player" => include("full_name" => "Will Vest"),
      "decision" => "(S, 1)"
    )
    expect(json_body.dig("data", "details", "insights", "teams", "home")).to include(
      "run_differential" => 2,
      "hits" => 8,
      "errors" => 1,
      "runners_in_scoring_position" => { "hits" => 1, "at_bats" => 1 }
    )
    expect(json_body.dig("data", "details", "plate_appearances", 0)).to include(
      "event_type" => "single",
      "plate_appearance_number" => 1
    )
    expect(json_body.dig("data", "details", "plate_appearances", 0, "pitches", 0)).to include(
      "pitch_type" => "FF",
      "release_speed" => 96.4
    )
  end

  it "returns future preview and scheduled games from the upcoming endpoint" do
    upcoming_game = create_game(
      schedule: @schedule,
      home_team: @guardians,
      away_team: @tigers,
      official_date: Date.current + 2.days,
      scheduled_at: Time.current + 2.days,
      status: "scheduled"
    )
    create_game(
      schedule: @schedule,
      official_date: Date.current - 1.day,
      scheduled_at: Time.current - 1.day,
      status: "final"
    )

    get upcoming_api_games_path, params: { team_id: @tigers.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |game| game.fetch("id") }).to include(upcoming_game.id)
    expect(json_body.fetch("data")).to all(include("status" => satisfy { |status| %w[preview scheduled].include?(status) }))
  end
end
