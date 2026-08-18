require "rails_helper"

RSpec.describe MlbTradeDetailsDownloader do
  it "downloads every participant sharing an MLB trade id" do
    downloader = described_class.new(mlb_transaction_id: 642_337)
    payload = {
      "transactions" => [
        { "id" => 642_337, "typeCode" => "TR", "person" => { "id" => 695_578 } },
        { "id" => 642_337, "typeCode" => "TR", "person" => { "id" => 665_742 } },
        { "id" => 642_337, "typeCode" => "SFA", "person" => { "id" => 123 } }
      ]
    }
    allow(downloader).to receive(:fetch_json).and_return(payload)

    result = downloader.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :participant_count)).to eq(2)
    expect(result.dig(:data, :payload, "transactions").pluck("typeCode")).to eq(%w[TR TR])
    expect(result.dig(:data, :source_url)).to include("transactionIds=642337")
  end

  it "rejects invalid ids and responses without trade participants" do
    expect(described_class.call(mlb_transaction_id: nil)[:success]).to be(false)

    downloader = described_class.new(mlb_transaction_id: 642_337)
    allow(downloader).to receive(:fetch_json).and_return({ "transactions" => [] })

    expect(downloader.call[:message]).to include("did not return trade participants")
  end
end
