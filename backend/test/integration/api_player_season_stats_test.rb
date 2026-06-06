require "test_helper"

class ApiPlayerSeasonStatsTest < ActionDispatch::IntegrationTest
  setup do
    @team = Team.create!(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    @player = Player.create!(mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera", team: @team)
    @stat_type = StatType.create!(name: "war", label: "WAR", category: "batting")
    @player_season_stat = PlayerSeasonStat.create!(
      player: @player,
      stat_type: @stat_type,
      season: 2024,
      value: 3.2
    )
  end

  test "lists player season stats" do
    get api_player_season_stats_url, as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal 1, body.fetch("data").length
    assert_equal @player_season_stat.id, body.dig("data", 0, "id")
    assert_equal "3.2", body.dig("data", 0, "value")
  end

  test "shows a player season stat" do
    get api_player_season_stat_url(@player_season_stat), as: :json

    assert_response :success

    body = JSON.parse(response.body)

    assert_equal @player_season_stat.id, body.dig("data", "id")
    assert_equal 2024, body.dig("data", "season")
  end

  test "creates a player season stat" do
    assert_difference("PlayerSeasonStat.count", 1) do
      post api_player_season_stats_url,
           params: {
             player_season_stat: {
               player_id: @player.id,
               stat_type_id: @stat_type.id,
               season: 2025,
               value: "4.7"
             }
           },
           as: :json
    end

    assert_response :created

    body = JSON.parse(response.body)

    assert_equal 2025, body.dig("data", "season")
    assert_equal "4.7", body.dig("data", "value")
  end

  test "updates a player season stat" do
    patch api_player_season_stat_url(@player_season_stat),
          params: {
            player_season_stat: {
              value: "5.1"
            }
          },
          as: :json

    assert_response :success
    assert_equal BigDecimal("5.1"), @player_season_stat.reload.value
  end

  test "destroys a player season stat" do
    assert_difference("PlayerSeasonStat.count", -1) do
      delete api_player_season_stat_url(@player_season_stat), as: :json
    end

    assert_response :no_content
  end
end
