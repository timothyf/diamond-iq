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
    expect(json_body.fetch("data").map { |player| player.fetch("last_name") }).to eq(["Ohtani"])
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

  it "filters players by first name and team name" do
    get api_players_path, params: { filter: { first_name: "mig", team_name: "tig" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters")).to eq({ "first_name" => "mig", "team_name" => "tig" })
    expect(json_body.fetch("data").map { |player| player.fetch("first_name") }).to eq(["Miguel"])
    expect(json_body.dig("data", 0, "team", "name")).to eq("Detroit Tigers")
  end

  it "filters players by last name" do
    get api_players_path, params: { filter: { last_name: "out" } }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(1)
    expect(json_body.dig("meta", "filters")).to eq({ "last_name" => "out" })
    expect(json_body.fetch("data").map { |player| player.fetch("last_name") }).to eq(["Trout"])
  end

  it "filters players by a combined name query across first and last name" do
    get api_players_path, params: { filter: { name: "mig" }, per_page: 10 }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "filters")).to eq({ "name" => "mig" })
    expect(json_body.fetch("data").map { |player| player.values_at("first_name", "last_name") }).to eq([["Miguel", "Cabrera"]])

    get api_players_path, params: { filter: { name: "out" }, per_page: 10 }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").map { |player| player.values_at("first_name", "last_name") }).to eq([["Mike", "Trout"]])
  end

  it "sorts players by team name descending" do
    get api_players_path, params: { sort: "-team_name" }

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "sort")).to eq("-team_name")
    expect(json_body.fetch("data").map { |player| [player.fetch("first_name"), player.fetch("last_name")] }).to eq(
      [["Miguel", "Cabrera"], ["Shohei", "Ohtani"], ["Mike", "Trout"]]
    )
  end
end
