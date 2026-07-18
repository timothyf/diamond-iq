require "rails_helper"

RSpec.describe MlbPlayerTeamHistoriesSync do
  it "synchronizes selected players and aggregates transaction and tenure counts" do
    first = create_player(attributes: { mlb_id: 656_427 })
    create_player(attributes: { mlb_id: 669_360 })
    allow(MlbPlayerTransactionsDownloader).to receive(:call).and_return(
      success: true,
      data: { payload: { "transactions" => [] }, source_url: "https://example.test", fetched_at: Time.current.iso8601 }
    )
    allow(MlbPlayerTeamHistoryImporter).to receive(:call).and_return(
      success: true,
      data: { transaction_count: 8, tenure_count: 5 }
    )

    result = described_class.call(mlb_ids: first.mlb_id)

    expect(result[:success]).to be(true)
    expect(result[:data]).to include(
      selected_player_count: 1,
      synchronized_player_count: 1,
      transaction_count: 8,
      tenure_count: 5
    )
    expect(MlbPlayerTransactionsDownloader).to have_received(:call).with(player_mlb_id: first.mlb_id)
  end
end
