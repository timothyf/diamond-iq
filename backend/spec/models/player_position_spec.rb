require "rails_helper"

RSpec.describe PlayerPosition, type: :model do
  it "is valid with source and synchronization metadata" do
    expect(create_player_position).to be_valid
  end

  it "allows the same position in different season scopes" do
    player = create_player
    position = create_position

    create_player_position(player: player, position: position, attributes: { season: nil })
    seasonal = described_class.new(
      player: player,
      position: position,
      season: 2025,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(seasonal).to be_valid
    expect(seasonal.season).to eq(2025)
  end

  it "prevents duplicate assignments in the same scope" do
    player = create_player
    position = create_position
    create_player_position(player: player, position: position, attributes: { season: 2025 })

    duplicate = described_class.new(
      player: player,
      position: position,
      season: 2025,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:position_id]).to include("has already been taken")
  end

  it "permits only one primary position per player and season scope" do
    player = create_player
    create_player_position(
      player: player,
      position: create_position,
      attributes: { season: 2025, is_primary: true }
    )

    second_primary = described_class.new(
      player: player,
      position: create_position,
      season: 2025,
      is_primary: true,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(second_primary).not_to be_valid
    expect(second_primary.errors[:is_primary]).to include("has already been assigned for this player and season")
  end

  it "separates current and seasonal assignments" do
    current = create_player_position(attributes: { season: nil })
    seasonal = create_player_position(attributes: { season: 2024 })

    expect(described_class.current).to contain_exactly(current)
    expect(described_class.for_season(2024)).to contain_exactly(seasonal)
  end
end
