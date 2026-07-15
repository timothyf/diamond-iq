require "rails_helper"

RSpec.describe MlbPlayerProfilesSync do
  it "batches players without profiles and aggregates import counts" do
    first = create_player(attributes: { mlb_id: 700_270 })
    second = create_player(attributes: { mlb_id: 669_360 })
    existing = create_player(attributes: { mlb_id: 680_776 })
    create_player_profile(player: existing)

    allow(MlbPlayerProfilesDownloader).to receive(:call) do |mlb_ids:|
      {
        success: true,
        message: "Downloaded",
        data: {
          payload: { "people" => mlb_ids.map { |mlb_id| { "id" => mlb_id } } },
          requested_mlb_ids: mlb_ids,
          fetched_at: "2026-07-14T21:00:00Z"
        }
      }
    end
    allow(MlbPlayerProfilesImporter).to receive(:call).and_return(
      success: true,
      message: "Imported",
      data: {
        profile_count: 1,
        created_profile_count: 1,
        updated_profile_count: 0,
        position_assignment_count: 1,
        missing_player_count: 0,
        missing_mlb_ids: []
      }
    )

    result = described_class.call(batch_size: 1)

    expect(result[:success]).to be(true)
    expect(result[:message]).to eq("Synchronized 2 MLB player profiles")
    expect(result[:data]).to include(
      selected_player_count: 2,
      profile_count: 2,
      created_profile_count: 2,
      batch_count: 2
    )
    expect(MlbPlayerProfilesDownloader).to have_received(:call).with(mlb_ids: [ first.mlb_id ]).once
    expect(MlbPlayerProfilesDownloader).to have_received(:call).with(mlb_ids: [ second.mlb_id ]).once
  end

  it "can refresh selected existing profiles" do
    player = create_player(attributes: { mlb_id: 700_270 })
    create_player_profile(player: player)
    allow(MlbPlayerProfilesDownloader).to receive(:call).and_return(success: false, message: "Stop after selection", data: {})

    result = described_class.call(only_missing: false, mlb_ids: player.mlb_id)

    expect(result[:success]).to be(false)
    expect(result.dig(:data, :selected_player_count)).to eq(1)
    expect(MlbPlayerProfilesDownloader).to have_received(:call).with(mlb_ids: [ player.mlb_id ])
  end

  it "returns success without an API request when no profiles are missing" do
    player = create_player
    create_player_profile(player: player)
    expect(MlbPlayerProfilesDownloader).not_to receive(:call)

    result = described_class.call

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :selected_player_count)).to eq(0)
    expect(result.dig(:data, :batch_count)).to eq(0)
  end
end
