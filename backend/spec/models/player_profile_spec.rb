require "rails_helper"

RSpec.describe PlayerProfile, type: :model do
  it "is valid with synchronization metadata" do
    expect(create_player_profile).to be_valid
  end

  it "requires one profile per player" do
    player = create_player
    create_player_profile(player: player)

    duplicate = described_class.new(
      player: player,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:player_id]).to include("has already been taken")
  end

  it "validates handedness values" do
    profile = build_profile(bats: "B", throws: "S")

    expect(profile).not_to be_valid
    expect(profile.errors[:bats]).to include("is not included in the list")
    expect(profile.errors[:throws]).to include("is not included in the list")
  end

  it "calculates age for a supplied date" do
    profile = build_profile(birth_date: Date.new(2000, 7, 15))

    expect(profile.age(on: Date.new(2026, 7, 14))).to eq(25)
    expect(profile.age(on: Date.new(2026, 7, 15))).to eq(26)
  end

  it "formats height stored as total inches" do
    expect(build_profile(height_inches: 74).formatted_height).to eq("6' 2\"")
  end

  it "builds an MLB headshot URL from the imported headshot id" do
    profile = build_profile(headshot_id: "680776")

    expect(profile.headshot_url).to eq(
      "https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/680776/headshot/67/current"
    )
  end

  it "prefers a manually configured headshot URL" do
    profile = build_profile(
      headshot_id: "680776",
      headshot_url_override: "https://example.test/custom-headshot.png"
    )

    expect(profile.headshot_url).to eq("https://example.test/custom-headshot.png")
  end

  it "does not build a headshot URL from an invalid id" do
    expect(build_profile(headshot_id: "invalid/id").headshot_url).to be_nil
  end

  def build_profile(attributes = {})
    described_class.new(
      {
        player: create_player,
        source_name: "MLB Stats API",
        last_synced_at: Time.current
      }.merge(attributes)
    )
  end
end
