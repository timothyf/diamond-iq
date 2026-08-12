require "rails_helper"

RSpec.describe MlbPlayerProfilesImporter do
  let(:player) { create_player(attributes: { mlb_id: 700_270, first_name: "Old", last_name: "Name" }) }
  let(:fetched_at) { Time.zone.parse("2026-07-14 21:00:00") }
  let(:person) do
    {
      "id" => 700_270,
      "firstName" => "Yilber",
      "lastName" => "Díaz",
      "useName" => "Yilber",
      "useLastName" => "Díaz",
      "birthDate" => "2000-08-19",
      "height" => "6' 0\"",
      "weight" => 190,
      "mlbDebutDate" => "2024-07-08",
      "batSide" => { "code" => "R" },
      "pitchHand" => { "code" => "R" },
      "primaryPosition" => {
        "code" => "1",
        "name" => "Pitcher",
        "type" => "Pitcher",
        "abbreviation" => "P"
      },
      "currentTeam" => { "id" => 512, "name" => "Toledo Mud Hens", "parentOrgId" => 116 }
    }
  end

  def import(payload:, requested_mlb_ids: [ 700_270 ], at: fetched_at)
    described_class.call(payload: payload, requested_mlb_ids: requested_mlb_ids, fetched_at: at)
  end

  it "idempotently imports profile attributes, names, raw data, and primary position" do
    player

    first_result = import(payload: { "people" => [ person ] })
    second_result = import(payload: { "people" => [ person ] }, at: fetched_at + 1.hour)

    expect(first_result[:success]).to be(true)
    expect(second_result[:success]).to be(true)
    expect(PlayerProfile.count).to eq(1)
    expect(PlayerPosition.count).to eq(1)

    expect(player.reload).to have_attributes(first_name: "Yilber", last_name: "Díaz")
    expect(player.profile).to have_attributes(
      birth_date: Date.new(2000, 8, 19),
      height_inches: 72,
      weight_pounds: 190,
      bats: "R",
      throws: "R",
      mlb_debut_date: Date.new(2024, 7, 8),
      headshot_id: "700270",
      source_name: "MLB Stats API",
      last_synced_at: fetched_at + 1.hour
    )
    expect(player.profile.raw_data).to eq(person)
    expect(player.primary_position).to have_attributes(abbreviation: "P", position_type: "pitcher")
    expect(first_result.dig(:data, :created_profile_count)).to eq(1)
    expect(second_result.dig(:data, :created_profile_count)).to eq(0)
    expect(second_result.dig(:data, :updated_profile_count)).to eq(1)
  end

  it "reports requested MLB ids that are not returned" do
    player

    result = import(payload: { "people" => [ person ] }, requested_mlb_ids: [ 700_270, 999_999 ])

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :missing_player_count)).to eq(1)
    expect(result.dig(:data, :missing_mlb_ids)).to eq([ 999_999 ])
  end

  it "skips returned people that do not exist in NineLens" do
    result = import(payload: { "people" => [ person ] })

    expect(result[:success]).to be(true)
    expect(result.dig(:data, :profile_count)).to eq(0)
    expect(result.dig(:data, :missing_mlb_ids)).to eq([ 700_270 ])
    expect(PlayerProfile.count).to eq(0)
  end

  it "rolls back the batch when a person payload is invalid" do
    player

    result = import(payload: { "people" => [ person, { "firstName" => "Missing id" } ] })

    expect(result[:success]).to be(false)
    expect(result.dig(:data, :errors)).to include("Person payload is missing id")
    expect(PlayerProfile.count).to eq(0)
  end
end
