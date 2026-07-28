require "rails_helper"

RSpec.describe "Acquisition discovery", type: :request do
  let(:organization) { create_team(name: "Detroit Tigers", abbreviation: "DET") }
  let(:other_team) { create_team(name: "Seattle Mariners", abbreviation: "SEA") }
  let(:outfield) { create_position(abbreviation: "OF", name: "Outfield", position_type: "outfielder") }
  let(:pitcher_position) { create_position(abbreviation: "P", name: "Pitcher", position_type: "pitcher") }
  let(:ops) { create_stat_type(name: "ops", label: "OPS", category: "batting") }

  before do
    @best = candidate("Best", "Fit", position: outfield, bats: "L", ops_value: 0.910)
    @alternative = candidate("Similar", "Option", position: outfield, bats: "L", ops_value: 0.830)
    candidate("Wrong", "Position", position: pitcher_position, bats: "L", ops_value: 0.950)
    candidate("Internal", "Player", position: outfield, bats: "L", ops_value: 0.980, team: organization)
  end

  it "creates reusable needs, discovers ranked candidates, calculates entry fit, and returns alternatives" do
    post api_need_profiles_path, params: {
      team_id: organization.id,
      name: "Left-handed outfield impact",
      description: "Deadline lineup need",
      criteria: {
        position_types: [ "outfielder" ],
        bats: [ "L" ],
        age: { max: 31 },
        performance: [ { stat_key: "ops", direction: "higher", target: 0.850 } ]
      },
      weights: { position: 20, handedness: 15, age: 10, performance: 55 }
    }

    expect(response).to have_http_status(:created)
    profile_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "weights", "performance")).to eq(55)

    post api_watchlists_path, params: {
      name: "Calculated deadline targets",
      description: "System-ranked candidates",
      need_profile_id: profile_id
    }
    watchlist_id = json_body.dig("data", "id")

    get discovery_api_watchlist_path(watchlist_id), params: { min_fit: 80 }

    expect(response).to have_http_status(:ok)
    candidates = json_body.fetch("data")
    expect(candidates.pluck("player").pluck("full_name")).to eq([ "Best Fit", "Similar Option" ])
    expect(candidates.first.fetch("calculated_fit_score")).to eq(100.0)
    expect(candidates.first.dig("fit_breakdown", "components", "performance", "targets", 0))
      .to include("actual" => 0.91, "target" => 0.85)

    post api_watchlist_watchlist_entries_path(watchlist_id), params: { player_id: @best.id }

    expect(response).to have_http_status(:created)
    entry_id = json_body.dig("data", "id")
    expect(json_body.dig("data", "calculated_fit_score")).to eq(100.0)
    expect(json_body.dig("data", "fit_calculated_at")).to be_present

    get alternatives_api_watchlist_entry_path(entry_id)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", 0, "player", "full_name")).to eq("Similar Option")
    expect(json_body.dig("data", 0, "similarity_score")).to be_present
    expect(json_body.dig("data", 0, "alternative_score")).to be_present
  end

  it "supports discovery filters beyond the reusable need profile" do
    profile = NeedProfile.create!(
      team: organization,
      name: "Outfield",
      criteria: { position_types: [ "outfielder" ] },
      weights: {}
    )
    watchlist = Watchlist.create!(name: "Filtered targets", need_profile: profile)

    get discovery_api_watchlist_path(watchlist), params: { bats: "R" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("data")).to eq([])
  end

  private

  def candidate(first_name, last_name, position:, bats:, ops_value:, team: other_team)
    player = create_player(team: team, attributes: { first_name: first_name, last_name: last_name })
    create_player_profile(player: player, attributes: { bats: bats, birth_date: Date.new(1999, 4, 12) })
    create_player_position(player: player, position: position, attributes: { is_primary: true })
    create_player_season_stat(
      player: player,
      stat_type: ops,
      attributes: { season: 2026, value: ops_value, team: team, scope_type: "combined", scope_key: "TOT" }
    )
    player
  end
end
