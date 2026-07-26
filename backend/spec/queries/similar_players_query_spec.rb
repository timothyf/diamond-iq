require "rails_helper"

RSpec.describe SimilarPlayersQuery do
  it "ranks same-season statistical neighbors and explains the closest metrics" do
    position = create_position(abbreviation: "CF", name: "Center Fielder", position_type: "outfielder")
    target = create_player(attributes: { first_name: "Target", last_name: "Hitter" })
    close_match = create_player(attributes: { first_name: "Close", last_name: "Match" })
    distant_match = create_player(attributes: { first_name: "Distant", last_name: "Match" })
    [ target, close_match, distant_match ].each do |candidate|
      create_player_position(player: candidate, position: position, attributes: { is_primary: true })
    end

    stat_types = {
      plateAppearances: create_stat_type(name: "plateAppearances", label: "PA", category: "batting"),
      homeRuns: create_stat_type(name: "homeRuns", label: "HR", category: "batting"),
      baseOnBalls: create_stat_type(name: "baseOnBalls", label: "BB", category: "batting"),
      strikeOuts: create_stat_type(name: "strikeOuts", label: "SO", category: "batting"),
      stolenBases: create_stat_type(name: "stolenBases", label: "SB", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      obp: create_stat_type(name: "obp", label: "OBP", category: "batting"),
      slg: create_stat_type(name: "slg", label: "SLG", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting")
    }
    values = {
      target => [ 500, 25, 50, 120, 12, 0.280, 0.355, 0.480, 0.835 ],
      close_match => [ 510, 26, 48, 117, 11, 0.278, 0.351, 0.477, 0.828 ],
      distant_match => [ 500, 5, 18, 180, 1, 0.205, 0.248, 0.310, 0.558 ]
    }

    values.each do |candidate, candidate_values|
      stat_types.values.zip(candidate_values).each do |stat_type, value|
        create_player_season_stat(
          player: candidate,
          stat_type: stat_type,
          attributes: { season: 2026, value: value, team: nil, scope_type: "combined", scope_key: "TOT" }
        )
      end
    end

    result = described_class.new(player: target, season: 2026, category: "batting").result

    expect(result).to include(season: 2026, category: "batting")
    expect(result.fetch(:matches).first).to include(
      player: hash_including(id: close_match.id, full_name: "Close Match"),
      same_position_type: true,
      shared_metric_count: 8
    )
    expect(result.fetch(:matches).first.fetch(:similarity_score))
      .to be > result.fetch(:matches).second.fetch(:similarity_score)
    expect(result.fetch(:matches).first.fetch(:closest_metrics)).to all(
      include(:key, :label, :target_value, :candidate_value)
    )
  end

  it "returns no matches when the player lacks enough comparable metrics" do
    player = create_player
    avg = create_stat_type(name: "avg", label: "AVG", category: "batting")
    create_player_season_stat(player: player, stat_type: avg, attributes: { season: 2026, value: 0.275 })

    result = described_class.new(player: player, season: 2026, category: "batting").result

    expect(result.fetch(:matches)).to be_empty
  end
end
