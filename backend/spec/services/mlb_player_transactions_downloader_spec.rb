require "rails_helper"

RSpec.describe MlbPlayerTransactionsDownloader do
  it "downloads a full transaction history for one player" do
    downloader = described_class.new(
      player_mlb_id: 656_427,
      start_date: Date.new(2017, 1, 1),
      end_date: Date.new(2026, 7, 17)
    )
    payload = { "transactions" => [ { "id" => 716_640, "typeCode" => "TR" } ] }

    allow(downloader).to receive(:fetch_json) do |url|
      query = Rack::Utils.parse_nested_query(URI(url).query)
      expect(URI(url).path).to eq("/api/v1/transactions")
      expect(query).to include(
        "playerId" => "656427",
        "startDate" => "01/01/2017",
        "endDate" => "07/17/2026"
      )
      payload
    end

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :payload)).to eq(payload)
    expect(result.dig(:data, :transaction_count)).to eq(1)
    expect(result.dig(:data, :source_url)).to include("playerId=656427")
  end

  it "rejects invalid inputs and malformed responses" do
    expect(described_class.call(player_mlb_id: nil)[:message]).to eq("Player MLB id must be a positive integer")

    downloader = described_class.new(player_mlb_id: 656_427)
    allow(downloader).to receive(:fetch_json).and_return({ "records" => [] })
    expect(downloader.call[:message]).to eq("MLB transactions response must include a transactions array")
  end
end
