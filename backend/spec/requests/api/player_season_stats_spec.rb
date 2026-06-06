require "rails_helper"

RSpec.describe "Api::PlayerSeasonStats", type: :request do
  before do
    @team = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit",
      team_code: "det",
      file_code: "det"
    )
    @player = create_player(team: @team, attributes: { mlb_id: 408234, first_name: "Miguel", last_name: "Cabrera" })
    @stat_type = create_stat_type(name: "war", label: "WAR", category: "batting")
    @player_season_stat = create_player_season_stat(
      player: @player,
      stat_type: @stat_type,
      attributes: { season: 2024, value: 3.2 }
    )
  end

  it "lists player season stats" do
    get api_player_season_stats_path, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data").length).to eq(1)
    expect(json_body.dig("data", 0, "id")).to eq(@player_season_stat.id)
    expect(json_body.dig("data", 0, "value")).to eq("3.2")
  end

  it "shows a player season stat" do
    get api_player_season_stat_path(@player_season_stat), as: :json

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "id")).to eq(@player_season_stat.id)
    expect(json_body.dig("data", "season")).to eq(2024)
  end

  it "creates a player season stat" do
    expect do
      post api_player_season_stats_path,
           params: {
             player_season_stat: {
               player_id: @player.id,
               stat_type_id: @stat_type.id,
               season: 2025,
               value: "4.7"
             }
           },
           as: :json
    end.to change(PlayerSeasonStat, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(json_body.dig("data", "season")).to eq(2025)
    expect(json_body.dig("data", "value")).to eq("4.7")
  end

  it "returns validation errors for invalid create input" do
    post api_player_season_stats_path,
         params: {
           player_season_stat: {
             player_id: @player.id,
             stat_type_id: @stat_type.id,
             season: nil,
             value: nil
           }
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_body.fetch("errors")).to include("Season can't be blank", "Value can't be blank")
  end

  it "updates a player season stat" do
    patch api_player_season_stat_path(@player_season_stat),
          params: { player_season_stat: { value: "5.1" } },
          as: :json

    expect(response).to have_http_status(:ok)
    expect(@player_season_stat.reload.value).to eq(BigDecimal("5.1"))
  end

  it "destroys a player season stat" do
    expect do
      delete api_player_season_stat_path(@player_season_stat), as: :json
    end.to change(PlayerSeasonStat, :count).by(-1)

    expect(response).to have_http_status(:no_content)
  end
end
