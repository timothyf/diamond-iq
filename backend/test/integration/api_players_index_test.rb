require "test_helper"

class ApiPlayersIndexTest < ActionDispatch::IntegrationTest
  setup do
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

    @miguel = Player.create!(mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera", team: @tigers)
    @shohei = Player.create!(mlb_id: 660271, first_name: "Shohei", last_name: "Ohtani", team: @dodgers)
    @mike = Player.create!(mlb_id: 545361, first_name: "Mike", last_name: "Trout", team: @angels)
  end

  test "returns paginated players with metadata" do
    get api_players_url, params: { page: 2, per_page: 1, sort: "last_name" }, as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 2, body.dig("meta", "page")
    assert_equal 1, body.dig("meta", "per_page")
    assert_equal 3, body.dig("meta", "total_count")
    assert_equal 3, body.dig("meta", "total_pages")
    assert_equal "last_name", body.dig("meta", "sort")
    assert_equal ["Ohtani"], body.fetch("data").map { |player| player.fetch("last_name") }
    assert_equal "Shohei", body.dig("data", 0, "first_name")
    assert_equal "Ohtani", body.dig("data", 0, "last_name")
    assert_equal "Los Angeles Dodgers", body.dig("data", 0, "team", "name")
    assert_equal "LAD", body.dig("data", 0, "team", "abbreviation")
    assert_equal "Dodgers", body.dig("data", 0, "team", "team_name")
  end

  test "filters players by first name and team name" do
    get api_players_url,
        params: { filter: { first_name: "mig", team_name: "tig" } },
        as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body.dig("meta", "total_count")
    assert_equal(
      { "first_name" => "mig", "team_name" => "tig" },
      body.dig("meta", "filters")
    )
    assert_equal ["Miguel"], body.fetch("data").map { |player| player.fetch("first_name") }
    assert_equal "Detroit Tigers", body.dig("data", 0, "team", "name")
  end

  test "filters players by last name" do
    get api_players_url,
        params: { filter: { last_name: "out" } },
        as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body.dig("meta", "total_count")
    assert_equal({ "last_name" => "out" }, body.dig("meta", "filters"))
    assert_equal ["Trout"], body.fetch("data").map { |player| player.fetch("last_name") }
  end

  test "sorts players by team name descending" do
    get api_players_url, params: { sort: "-team_name" }, as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal "-team_name", body.dig("meta", "sort")
    assert_equal(
      [["Miguel", "Cabrera"], ["Shohei", "Ohtani"], ["Mike", "Trout"]],
      body.fetch("data").map { |player| [player.fetch("first_name"), player.fetch("last_name")] }
    )
  end

  private

  def create_team(attributes)
    Team.create!(attributes)
  end
end
