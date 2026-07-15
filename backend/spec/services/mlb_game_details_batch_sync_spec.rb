require "rails_helper"

RSpec.describe MlbGameDetailsBatchSync do
  it "continues after an unavailable game and reports the failure" do
    first = create_game(mlb_id: 800_001, official_date: Date.new(2026, 7, 15))
    second = create_game(mlb_id: 800_002, official_date: Date.new(2026, 7, 15))
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
  end

  it "rejects a reversed date range" do
    result = described_class.call(start_date: "2026-07-16", end_date: "2026-07-15")

    expect(result).to include(success: false, message: "End date must be on or after start date")
  end
end
