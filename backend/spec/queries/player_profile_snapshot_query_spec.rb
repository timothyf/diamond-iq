require "rails_helper"

RSpec.describe PlayerProfileSnapshotQuery do
  it "prefers a pitching overview for a player whose primary position is pitcher" do
    player = create_player
    pitcher = create_position(mlb_code: "1", abbreviation: "P", name: "Pitcher", position_type: "pitcher")
    create_player_position(player: player, position: pitcher, attributes: { is_primary: true })
    era = create_stat_type(name: "ERA", label: "ERA", category: "pitching")
    home_runs = create_stat_type(name: "homeRuns", label: "HR", category: "batting")
    create_player_season_stat(player: player, stat_type: era, attributes: { season: 2026, value: 2.85 })
    create_player_season_stat(player: player, stat_type: home_runs, attributes: { season: 2026, value: 1 })

    overview = described_class.new(player: player).result.fetch(:season_overview)

    expect(overview).to include(season: 2026, category: "pitching", preferred_category: "pitching")
    expect(overview.fetch(:stats)).to include(hash_including(key: "ERA", value: "2.85"))
    expect(overview.fetch(:stats)).not_to include(hash_including(key: "homeRuns"))
  end

  it "returns a stable empty overview when season statistics are unavailable" do
    player = create_player

    expect(described_class.new(player: player).result.fetch(:season_overview)).to eq(
      season: nil,
      category: "batting",
      preferred_category: "batting",
      stats: []
    )
  end
end
