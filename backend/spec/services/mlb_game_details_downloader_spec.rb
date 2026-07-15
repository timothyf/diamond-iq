require "rails_helper"

RSpec.describe MlbGameDetailsDownloader do
  it "downloads both the MLB box score and live feed" do
    downloader = described_class.new(mlb_id: 823_443)
    allow(downloader).to receive(:fetch_json) do |url|
      url.include?("boxscore") ? { "teams" => {} } : { "liveData" => {} }
    end

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :boxscore)).to eq("teams" => {})
    expect(result.dig(:data, :live_feed)).to eq("liveData" => {})
    expect(result.dig(:data, :boxscore_source_url)).to end_with("/v1/game/823443/boxscore")
    expect(result.dig(:data, :live_feed_source_url)).to end_with("/v1.1/game/823443/feed/live")
    expect(downloader).to have_received(:fetch_json).twice
  end

  it "rejects an invalid MLB game id before downloading" do
    downloader = described_class.new(mlb_id: "bad")
    expect(downloader).not_to receive(:fetch_json)

    expect(downloader.call).to include(success: false, message: "MLB game id must be a positive integer")
  end
end
