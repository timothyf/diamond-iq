require "rails_helper"

RSpec.describe "selective Statcast pitch synchronization" do
  def game_for(date:, mlb_id:)
    schedule = create_schedule(season: date.year)
    create_game(schedule: schedule, official_date: date, mlb_id: mlb_id, game_type: "R")
  end

  it "excludes completed games from the estimate and does not download an all-complete range" do
    game = game_for(date: Date.new(2026, 7, 1), mlb_id: 700_001)
    game.update!(pitch_data_complete_at: Time.current, pitch_data_row_count: 150)

    estimate = PitchDataSyncTaskEstimate.call(start_date: "2026-07-01", end_date: "2026-07-01", game_types: "R", chunk_days: 1)

    expect(estimate).to include(game_count: 0, already_complete_game_count: 1)
    expect(PitchDataDownloader).not_to receive(:call)

    result = PitchDataBatchSync.call(start_date: "2026-07-01", end_date: "2026-07-01", game_types: "R", chunk_days: 1)

    expect(result).to include(success: true)
    expect(result.dig(:data, :already_complete_game_count)).to eq(1)
    expect(result.dig(:data, :downloaded_count)).to eq(0)
  end

  it "includes completed games when replacement is explicitly requested" do
    game = game_for(date: Date.new(2026, 7, 2), mlb_id: 700_002)
    game.update!(pitch_data_complete_at: 1.day.ago, pitch_data_row_count: 120)
    PitchDatum.create!(game: game, game_pk: game.mlb_id, at_bat_number: 1, pitch_number: 1, raw_data: { "old" => true })
    allow(PitchDataDownloader).to receive(:call).and_return(
      success: true,
      data: { rows: [ { "game_pk" => game.mlb_id.to_s, "at_bat_number" => "2", "pitch_number" => "1", "game_date" => "2026-07-02" } ] }
    )

    result = PitchDataBatchSync.call(
      start_date: "2026-07-02", end_date: "2026-07-02", game_types: "R", chunk_days: 1, replace_existing: true
    )

    expect(result).to include(success: true)
    expect(PitchDatum.where(game_id: game.id).pluck(:at_bat_number, :pitch_number)).to eq([ [ 2, 1 ] ])
    expect(game.reload.pitch_data_complete_at).to be_present
    expect(game.pitch_data_row_count).to eq(1)
  end
end
