require "rails_helper"

RSpec.describe MlbScheduleImporter do
  let(:sync_time) { Time.zone.parse("2026-07-14T12:00:00Z") }

  it "upserts the schedule and games idempotently while resolving teams and probable pitchers" do
    payload = schedule_payload(games: [ game_payload ])

    first_result = import(payload)
    game = Game.find_by!(mlb_id: 823_443)
    second_payload = schedule_payload(games: [ game_payload(home_score: 5, away_score: 3, detailed_status: "Final", abstract_status: "Final") ])
    second_result = import(second_payload, fetched_at: sync_time + 1.hour, game_types: [ "R" ])

    expect(first_result[:success]).to be(true)
    expect(first_result.dig(:data, :created_game_count)).to eq(1)
    expect(first_result.dig(:data, :created_team_count)).to eq(2)
    expect(first_result.dig(:data, :created_player_count)).to eq(2)
    expect(second_result[:success]).to be(true)
    expect(second_result.dig(:data, :created_game_count)).to eq(0)
    expect(second_result.dig(:data, :updated_game_count)).to eq(1)
    expect(Schedule.count).to eq(1)
    expect(Game.count).to eq(1)
    expect(Team.count).to eq(2)
    expect(Player.count).to eq(2)
    expect(game.reload).to have_attributes(home_score: 5, away_score: 3, status: "final")
    expect(game.home_probable_pitcher.full_name).to eq("Tarik Skubal")
    expect(game.away_probable_pitcher.full_name).to eq("Paul Skenes")
    expect(game.raw_data.dig("status", "detailedState")).to eq("Final")
    expect(game.last_synced_at).to be_within(1.second).of(sync_time + 1.hour)
    expect(game.schedule.raw_data).to eq(second_payload)
    expect(game.schedule).to have_attributes(
      source_key: "mlb:schedule:1:2026-07-14:2026-07-14:R",
      schedule_type: "R"
    )
  end

  it "normalizes postponed games without discarding the MLB status detail" do
    result = import(schedule_payload(games: [ game_payload(detailed_status: "Postponed", abstract_status: "Preview") ]))

    expect(result[:success]).to be(true)
    expect(Game.first).to have_attributes(status: "postponed", detailed_status: "Postponed")
  end

  it "preserves both games in a doubleheader" do
    first_game = game_payload(game_pk: 823_450, game_number: 1, doubleheader: "Y")
    second_game = game_payload(game_pk: 823_451, game_number: 2, doubleheader: "Y", scheduled_at: "2026-07-14T23:30:00Z")

    result = import(schedule_payload(games: [ first_game, second_game ]))

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :game_count)).to eq(2)
    expect(Game.order(:game_number).pluck(:mlb_id, :game_number, :doubleheader)).to eq(
      [ [ 823_450, 1, "Y" ], [ 823_451, 2, "Y" ] ]
    )
  end

  it "imports games when probable pitchers have not been announced" do
    payload = game_payload
    payload["teams"]["home"].delete("probablePitcher")
    payload["teams"]["away"].delete("probablePitcher")

    result = import(schedule_payload(games: [ payload ]))

    expect(result[:success]).to be(true)
    expect(Game.first.home_probable_pitcher).to be_nil
    expect(Game.first.away_probable_pitcher).to be_nil
    expect(Player.count).to eq(0)
  end

  it "returns visible validation errors and rolls back the entire import" do
    invalid_game = game_payload
    invalid_game["teams"]["away"]["team"] = invalid_game.dig("teams", "home", "team").deep_dup

    result = import(schedule_payload(games: [ invalid_game ]))

    expect(result[:success]).to be(false)
    expect(result[:message]).to eq("MLB schedule import validation failed")
    expect(result.dig(:data, :errors)).to include("Away team must be different from the home team")
    expect(Schedule.count).to eq(0)
    expect(Game.count).to eq(0)
    expect(Team.count).to eq(0)
    expect(Player.count).to eq(0)
  end

  private

  def import(payload, fetched_at: sync_time, game_types: "R")
    described_class.call(
      payload: payload,
      start_date: "2026-07-14",
      end_date: "2026-07-14",
      game_types: game_types,
      sport_id: 1,
      source_url: "https://statsapi.mlb.com/api/v1/schedule?example=true",
      fetched_at: fetched_at
    )
  end

  def schedule_payload(games:)
    {
      "copyright" => "MLB",
      "totalGames" => games.length,
      "dates" => [ { "date" => "2026-07-14", "games" => games } ]
    }
  end

  def game_payload(
    game_pk: 823_443,
    game_number: 1,
    doubleheader: "N",
    scheduled_at: "2026-07-14T18:10:00Z",
    detailed_status: "Pre-Game",
    abstract_status: "Preview",
    home_score: 0,
    away_score: 0
  )
    {
      "gamePk" => game_pk,
      "link" => "/api/v1.1/game/#{game_pk}/feed/live",
      "gameType" => "R",
      "season" => "2026",
      "gameDate" => scheduled_at,
      "officialDate" => "2026-07-14",
      "status" => {
        "abstractGameState" => abstract_status,
        "detailedState" => detailed_status
      },
      "teams" => {
        "away" => {
          "team" => team_payload(id: 134, name: "Pittsburgh Pirates", abbreviation: "PIT", team_name: "Pirates", location_name: "Pittsburgh"),
          "score" => away_score,
          "probablePitcher" => { "id" => 694_973, "fullName" => "Paul Skenes" }
        },
        "home" => {
          "team" => team_payload(id: 116, name: "Detroit Tigers", abbreviation: "DET", team_name: "Tigers", location_name: "Detroit"),
          "score" => home_score,
          "probablePitcher" => { "id" => 669_373, "fullName" => "Tarik Skubal" }
        }
      },
      "venue" => { "id" => 2_399, "name" => "Comerica Park" },
      "gameNumber" => game_number,
      "doubleHeader" => doubleheader
    }
  end

  def team_payload(id:, name:, abbreviation:, team_name:, location_name:)
    {
      "id" => id,
      "name" => name,
      "abbreviation" => abbreviation,
      "teamName" => team_name,
      "locationName" => location_name,
      "shortName" => location_name,
      "teamCode" => abbreviation.downcase,
      "fileCode" => abbreviation.downcase
    }
  end
end
