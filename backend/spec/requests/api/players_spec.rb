require "rails_helper"

RSpec.describe "Api::Players", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    @dodgers = create_team(
      mlb_id: 119,
      name: "Los Angeles Dodgers",
      abbreviation: "LAD",
      team_name: "Dodgers",
      location_name: "Los Angeles",
      short_name: "Los Angeles",
      team_code: "lan",
      file_code: "la"
    )
    @angels = create_team(
      mlb_id: 108,
      name: "Los Angeles Angels",
      abbreviation: "LAA",
      team_name: "Angels",
      location_name: "Los Angeles",
      short_name: "Angels",
      team_code: "ana",
      file_code: "ana"
    )

    @miguel = create_player(team: @tigers, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    create_player(team: @dodgers, attributes: { mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani" })
    create_player(team: @angels, attributes: { mlb_id: 545361, first_name: "Mike", last_name: "Trout" })
  end

  it "returns paginated players with metadata" do
    get api_players_path, params: { page: 2, per_page: 1, sort: "last_name" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "page")).to eq(2)
    expect(json_body.dig("meta", "per_page")).to eq(1)
    expect(json_body.dig("meta", "total_count")).to eq(3)
    expect(json_body.dig("meta", "total_pages")).to eq(3)
    expect(json_body.dig("meta", "sort")).to eq("last_name")
    expect(json_body.fetch("data").map { |player| player.fetch("last_name") }).to eq([ "Ohtani" ])
    expect(json_body.dig("data", 0, "first_name")).to eq("Shohei")
    expect(json_body.dig("data", 0, "mlb_id")).to eq(660271)
    expect(json_body.dig("data", 0, "team", "name")).to eq("Los Angeles Dodgers")
    expect(json_body.dig("data", 0, "team", "abbreviation")).to eq("LAD")
    expect(json_body.dig("data", 0, "team", "team_name")).to eq("Dodgers")
  end

  it "returns a player with profile details" do
    create_player_profile(
      player: @miguel,
      attributes: {
        birth_date: Date.new(1983, 4, 18),
        height_inches: 76,
        weight_pounds: 267,
        bats: "R",
        throws: "R",
        mlb_debut_date: Date.new(2003, 6, 20),
        headshot_id: "408234",
        headshot_url_override: "https://example.test/miguel-cabrera.png"
      }
    )

    get api_player_path(@miguel)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "full_name")).to eq("Miguel Cabrera")
    expect(json_body.dig("data", "profile", "birth_date")).to eq("1983-04-18")
    expect(json_body.dig("data", "profile", "height_inches")).to eq(76)
    expect(json_body.dig("data", "profile", "formatted_height")).to eq("6' 4\"")
    expect(json_body.dig("data", "profile", "weight_pounds")).to eq(267)
    expect(json_body.dig("data", "profile", "bats")).to eq("R")
    expect(json_body.dig("data", "profile", "throws")).to eq("R")
    expect(json_body.dig("data", "profile", "mlb_debut_date")).to eq("2003-06-20")
    expect(json_body.dig("data", "profile", "headshot_url")).to eq("https://example.test/miguel-cabrera.png")
  end

  it "returns a null profile when profile data has not been synchronized" do
    get api_player_path(@miguel)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "profile")).to be_nil
  end

  it "returns a unified current-season, roster-history, pitch, and source profile" do
    profile = create_player_profile(player: @miguel)
    position = create_position(mlb_code: "5", abbreviation: "3B", name: "Third Base", position_type: "infielder")
    create_player_position(player: @miguel, position: position, attributes: { is_primary: true })
    historical_membership = create_team_membership(
      player: @miguel,
      team: @angels,
      starts_on: Date.current - 2.years,
      ends_on: Date.current - 1.year,
      roster_status: "active"
    )
    current_membership = create_team_membership(
      player: @miguel,
      team: @tigers,
      starts_on: Date.current - 30.days,
      roster_status: "D10",
      source_status_code: "D10",
      source_status_description: "Injured 10-Day"
    )
    current_membership.update!(roster_status: "injured_10_day")

    old_stat_type = create_stat_type(name: "hits", label: "H", category: "batting")
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_player_season_stat(player: @miguel, stat_type: old_stat_type, attributes: { season: 2025, value: 100 })
    create_player_season_stat(player: @miguel, stat_type: home_runs, attributes: { season: 2026, value: 18 })
    create_player_season_stat(
      player: @miguel,
      stat_type: home_runs,
      attributes: { season: 2026, team: nil, scope_type: "combined", scope_key: "TOT", value: 22 }
    )

    PitchDatum.create!(
      game_pk: 800_001,
      game_date: Date.current - 1.day,
      at_bat_number: 1,
      pitch_number: 1,
      batter: @miguel.mlb_id,
      launch_speed: 101.4,
      launch_angle: 22.0,
      fetched_at_utc: Time.current,
      raw_data: { "game_pk" => "800001", "at_bat_number" => "1", "pitch_number" => "1" }
    )
    PitchDatum.create!(
      game_pk: 800_002,
      game_date: Date.current,
      at_bat_number: 1,
      pitch_number: 1,
      pitcher: @miguel.mlb_id,
      type: "S",
      release_speed: 94.6,
      release_spin_rate: 2_350,
      fetched_at_utc: Time.current,
      raw_data: { "game_pk" => "800002", "at_bat_number" => "1", "pitch_number" => "1" }
    )

    get api_player_path(@miguel)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "season_overview", "season")).to eq(2026)
    expect(json_body.dig("data", "season_overview", "category")).to eq("batting")
    expect(json_body.dig("data", "season_overview", "stats")).to include(
      hash_including("key" => "homeRuns", "label" => "HR", "value" => "22.0", "scope_type" => "combined")
    )
    expect(json_body.dig("data", "current_membership")).to include(
      "id" => current_membership.id,
      "roster_status" => "injured_10_day",
      "injured" => true
    )
    expect(json_body.dig("data", "team_history").map { |membership| membership.dig("team", "id") }).to eq(
      [ @tigers.id, @angels.id ]
    )
    expect(json_body.dig("data", "team_history", 1, "id")).to eq(historical_membership.id)
    expect(json_body.dig("data", "recent_pitch_indicators", "batting")).to include(
      "pitches_seen" => 1,
      "average_exit_velocity" => 101.4,
      "hard_hit_percentage" => 100.0
    )
    expect(json_body.dig("data", "recent_pitch_indicators", "pitching")).to include(
      "pitch_count" => 1,
      "average_velocity" => 94.6,
      "strike_percentage" => 100.0
    )
    expect(json_body.dig("data", "source_metadata", "sources")).to include(
      "MLB Stats API",
      "Baseball Savant"
    )
    expect(json_body.dig("data", "source_metadata", "last_updated_at")).to be_present
    expect(json_body.dig("data", "profile", "id")).to eq(profile.id)
  end

  it "filters players by first name and team name" do
    get api_players_path, params: { filter: { first_name: "mig", team_name: "tig" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters")).to eq({ "first_name" => "mig", "team_name" => "tig" })
    expect(json_body.fetch("data").map { |player| player.fetch("first_name") }).to eq([ "Miguel" ])
    expect(json_body.dig("data", 0, "team", "name")).to eq("Detroit Tigers")
  end

  it "filters players by last name" do
    get api_players_path, params: { filter: { last_name: "out" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters")).to eq({ "last_name" => "out" })
    expect(json_body.fetch("data").map { |player| player.fetch("last_name") }).to eq([ "Trout" ])
  end

  it "filters players by a combined name query across first and last name" do
    get api_players_path, params: { filter: { name: "mig" }, per_page: 10 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to eq({ "name" => "mig" })
    expect(json_body.fetch("data").map { |player| player.values_at("first_name", "last_name") }).to eq([ [ "Miguel", "Cabrera" ] ])

    get api_players_path, params: { filter: { name: "out" }, per_page: 10 }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |player| player.values_at("first_name", "last_name") }).to eq([ [ "Mike", "Trout" ] ])
  end

  it "sorts players by team name descending" do
    get api_players_path, params: { sort: "-team_name" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "sort")).to eq("-team_name")
    expect(json_body.fetch("data").map { |player| [ player.fetch("first_name"), player.fetch("last_name") ] }).to eq(
      [ [ "Miguel", "Cabrera" ], [ "Shohei", "Ohtani" ], [ "Mike", "Trout" ] ]
    )
  end
end
