require "rails_helper"

RSpec.describe MlbGameDetailsBatchSync do
  it "continues after an unavailable game and reports the failure" do
    first = create_game(mlb_id: 800_001, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_002, official_date: Date.new(2026, 7, 15))
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    allow(MlbGameDetailsSync).to receive(:call).with(game: first).and_return(
      success: true,
      message: "Synchronized",
      data: { batting_line_count: 2, plate_appearance_count: 10 }
    )
    allow(MlbGameDetailsSync).to receive(:call).with(game: second).and_return(
      success: false,
      message: "HTTP 404: Not Found",
      data: {}
    )

    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15")

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :synchronized_game_count)).to eq(1)
    expect(result.dig(:data, :failed_game_count)).to eq(1)
    expect(result.dig(:data, :batting_line_count)).to eq(2)
    expect(result.dig(:data, :errors)).to include(hash_including(mlb_id: 800_002, message: "HTTP 404: Not Found"))
    expect(result.dig(:data, :analytics_refresh, :success)).to be(true)
    expect(DailyAnalyticsRefresh).to have_received(:call).with(dates: [ Date.new(2026, 7, 15) ])
  end

  it "rejects a reversed date range" do
    result = described_class.call(start_date: "2026-07-16", end_date: "2026-07-15")

    expect(result).to include(success: false, message: "End date must be on or after start date")
  end

  it "reports progress and stops safely between games when cancellation is requested" do
    first = create_game(mlb_id: 800_011, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_012, official_date: Date.new(2026, 7, 15))
    allow(DailyAnalyticsRefresh).to receive(:call).and_return(success: true, message: "ok", data: {})
    tracker = instance_double(MlbGameDetailsProgressTracker)
    allow(tracker).to receive(:start!)
    allow(tracker).to receive(:cancel_requested?).and_return(false, true)
    allow(tracker).to receive(:game_started!)
    allow(tracker).to receive(:game_finished!)
    allow(MlbGameDetailsSync).to receive(:call).with(game: first).and_return(success: true, message: "Synchronized", data: {})

    result = described_class.call(start_date: "2026-07-15", end_date: "2026-07-15", progress_tracker: tracker)

    expect(result).to include(success: true, message: "Cancelled after processing 1 of 2 MLB games")
    expect(result.dig(:data, :cancelled)).to be(true)
    expect(tracker).to have_received(:start!).with(total: 2)
    expect(tracker).to have_received(:game_started!).with(first)
    expect(tracker).to have_received(:game_finished!).with(game: first, success: true, message: "Synchronized")
    expect(MlbGameDetailsSync).not_to have_received(:call).with(game: second)
    expect(DailyAnalyticsRefresh).to have_received(:call).with(dates: [ Date.new(2026, 7, 15) ])
  end
end
