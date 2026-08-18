require "rails_helper"

RSpec.describe MlbTradesSync do
  it "downloads and imports each unique trade id" do
    allow(MlbTradeDetailsDownloader).to receive(:call).and_return(
      success: true,
      data: { payload: { "transactions" => [] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 }
    )
    allow(MlbTradeImporter).to receive(:call).and_return(
      success: true,
      data: { participant_count: 8 }
    )

    result = described_class.call(mlb_transaction_ids: [ 642_337, "642337", 700_001 ])

    expect(result[:success]).to be(true)
    expect(result[:data]).to include(
      selected_trade_count: 2,
      synchronized_trade_count: 2,
      participant_count: 16
    )
    expect(MlbTradeDetailsDownloader).to have_received(:call).twice
  end
end
