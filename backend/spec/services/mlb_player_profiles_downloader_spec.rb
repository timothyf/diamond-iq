require "rails_helper"

RSpec.describe MlbPlayerProfilesDownloader do
  it "downloads multiple hydrated player profiles" do
    downloader = described_class.new(mlb_ids: [ 700_270, 669_360 ])
    payload = { "people" => [ { "id" => 700_270 }, { "id" => 669_360 } ] }

    allow(downloader).to receive(:fetch_json) do |url|
      query = Rack::Utils.parse_nested_query(URI(url).query)
      expect(URI(url).path).to eq("/api/v1/people")
      expect(query).to include(
        "personIds" => "700270,669360",
        "hydrate" => "currentTeam"
      )
      payload
    end

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :payload)).to eq(payload)
    expect(result.dig(:data, :profile_count)).to eq(2)
    expect(result.dig(:data, :requested_mlb_ids)).to eq([ 700_270, 669_360 ])
    expect(result.dig(:data, :fetched_at)).to be_present
  end

  it "rejects empty and oversized requests before downloading" do
    empty_downloader = described_class.new(mlb_ids: [])
    expect(empty_downloader).not_to receive(:fetch_json)
    expect(empty_downloader.call[:message]).to eq("At least one player MLB id is required")

    oversized_downloader = described_class.new(mlb_ids: (1..101).to_a)
    expect(oversized_downloader).not_to receive(:fetch_json)
    expect(oversized_downloader.call[:message]).to eq("A profile request cannot exceed 100 players")
  end

  it "rejects malformed MLB responses" do
    downloader = described_class.new(mlb_ids: [ 700_270 ])
    allow(downloader).to receive(:fetch_json).and_return({ "players" => [] })

    expect(downloader.call[:message]).to eq("MLB people response must include a people array")
  end
end
