require "rails_helper"

RSpec.describe NeedProfileFitCalculator, type: :service do
  let(:organization) { create_team(name: "Detroit Tigers", abbreviation: "DET") }
  let(:candidate_team) { create_team(name: "Seattle Mariners", abbreviation: "SEA") }
  let(:player) { create_player(team: candidate_team, attributes: { first_name: "Lefty", last_name: "Target" }) }
  let(:position) { create_position(abbreviation: "RF", name: "Right Field", position_type: "outfielder") }
  let(:profile) do
    NeedProfile.create!(
      team: organization,
      name: "Left-handed impact outfielder",
      criteria: {
        position_types: [ "outfielder" ],
        bats: [ "L" ],
        age: { min: 24, max: 30 },
        performance: [ { stat_key: "ops", direction: "higher", target: 0.850 } ]
      },
      weights: { position: 25, handedness: 15, age: 10, performance: 50 }
    )
  end

  before do
    create_player_profile(player: player, attributes: { bats: "L", birth_date: Date.new(1999, 5, 10) })
    create_player_position(player: player, position: position, attributes: { is_primary: true })
    stat = create_stat_type(name: "ops", label: "OPS", category: "batting")
    create_player_season_stat(
      player: player,
      stat_type: stat,
      attributes: { season: 2026, value: 0.800, team: candidate_team, scope_type: "combined", scope_key: "TOT" }
    )
  end

  it "calculates a transparent weighted 0-100 fit from reusable profile criteria" do
    result = described_class.new(
      need_profile: profile,
      player: player,
      on: Date.new(2026, 7, 28)
    ).result

    expect(result[:score]).to eq(97.06)
    expect(result.dig(:breakdown, "components", "position")).to include("score" => 100.0, "matched" => true)
    expect(result.dig(:breakdown, "components", "handedness", "score")).to eq(100.0)
    expect(result.dig(:breakdown, "components", "performance", "targets", 0)).to include(
      "stat_key" => "ops",
      "target" => 0.85,
      "actual" => 0.8,
      "score" => 94.12
    )
    expect(result.dig(:breakdown, "weights", "performance")).to eq(50.0)
  end
end
