require "rails_helper"

RSpec.describe MlbRosterDownloader do
  it "downloads a hydrated dated roster payload" do
    downloader = described_class.new(
      team_mlb_id: 116,
      season: 2026,
      roster_type: "40Man",
      as_of: "2026-07-14"
    )
    payload = { "roster" => [ { "person" => { "id" => 123 } } ] }

    allow(downloader).to receive(:fetch_json) do |url|
      expect(URI(url).path).to eq("/api/v1/teams/116/roster")
      expect(Rack::Utils.parse_nested_query(URI(url).query)).to include(
        "rosterType" => "40Man",
        "season" => "2026",
        "date" => "2026-07-14",
        "hydrate" => "person"
      )
      payload
    end

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :payload)).to eq(payload)
    expect(result.dig(:data, :entry_count)).to eq(1)
    expect(result.dig(:data, :source_url)).to include("/teams/116/roster")
  end

  it "rejects invalid inputs before making a request" do
    downloader = described_class.new(team_mlb_id: nil, season: 2026)
    expect(downloader).not_to receive(:fetch_json)

    result = downloader.call

    expect(result[:success]).to be(false)
    expect(result[:message]).to eq("Team MLB id must be a positive integer")
  end

  it "rejects malformed MLB responses" do
    downloader = described_class.new(team_mlb_id: 116, season: 2026)
    allow(downloader).to receive(:fetch_json).and_return({ "people" => [] })

    expect(downloader.call[:message]).to eq("MLB roster response must include a roster array")
  end
end
