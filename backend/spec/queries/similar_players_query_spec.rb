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
    expect(result.fetch(:controls)).to include(
      available_seasons: [ 2026 ],
      mode: "season",
      selected_season: 2026,
      position_match: "any"
    )
    expect(result.fetch(:model_metrics)).to include(
      hash_including(key: "ops", label: "OPS", weight: 0.20),
      hash_including(key: "sb_rate", label: "SB / PA", weight: 0.05)
    )
    expect(result.fetch(:matches).first).to include(
      player: hash_including(id: close_match.id, full_name: "Close Match"),
      same_position_type: true,
      shared_metric_count: 8
    )
    expect(result.fetch(:matches).first.fetch(:similarity_score))
      .to be > result.fetch(:matches).second.fetch(:similarity_score)
    expect(result.fetch(:matches).first.fetch(:closest_metrics)).to all(
      include(:key, :label, :target_value, :candidate_value, :weight, :normalized_weight)
    )
    expect(result.fetch(:matches).first.fetch(:metrics_used).length).to eq(8)
    expect(result.fetch(:matches).first.fetch(:why_similar)).to include(
      match(/Closest statistical alignment/),
      match(/Same position group/)
    )
    expect(result.fetch(:matches).first.fetch(:metrics_used).sum { |metric| metric.fetch(:normalized_weight) })
      .to be_within(0.001).of(1.0)
  end


  it "uses playing-time-weighted rates across seasons in career mode" do
    target = create_player(attributes: { first_name: "Career", last_name: "Target" })
    candidate = create_player(attributes: { first_name: "Career", last_name: "Match" })
    stat_types = {
      pa: create_stat_type(name: "plateAppearances", label: "PA", category: "batting"),
      avg: create_stat_type(name: "avg", label: "AVG", category: "batting"),
      obp: create_stat_type(name: "obp", label: "OBP", category: "batting"),
      ops: create_stat_type(name: "ops", label: "OPS", category: "batting")
    }
    {
      target => {
        2025 => { pa: 100, avg: 0.200, obp: 0.280, ops: 0.600 },
        2026 => { pa: 300, avg: 0.300, obp: 0.380, ops: 0.900 }
      },
      candidate => {
        2025 => { pa: 200, avg: 0.260, obp: 0.340, ops: 0.780 },
        2026 => { pa: 200, avg: 0.280, obp: 0.360, ops: 0.820 }
      }
    }.each do |player, seasons|
      seasons.each do |season, values|
        values.each do |key, value|
          create_player_season_stat(
            player: player,
            stat_type: stat_types.fetch(key),
            attributes: { season: season, value: value, team: nil, scope_type: "combined", scope_key: "TOT" }
          )
        end
      end
    end

    result = described_class.new(player: target, season: 2026, category: "batting", mode: "career").result
    avg_metric = result.dig(:matches, 0, :metrics_used).find { |metric| metric.fetch(:key) == "avg" }

    expect(result).to include(mode: "career")
    expect(result.fetch(:controls)).to include(mode: "career", available_seasons: [ 2026, 2025 ])
    expect(avg_metric.fetch(:target_value)).to eq(0.275)
    expect(avg_metric.fetch(:candidate_value)).to eq(0.27)
    expect(result.fetch(:methodology)).to include("career statistics with playing-time-weighted rates among players active in the selected season")
  end


  it "filters candidates by age and position controls" do
    outfield = create_position(abbreviation: "CF", name: "Center Fielder", position_type: "outfielder")
    infield = create_position(abbreviation: "SS", name: "Shortstop", position_type: "infielder")
    target = create_player(attributes: { first_name: "Target", last_name: "Player" })
    same_group = create_player(attributes: { first_name: "Same", last_name: "Group" })
    wrong_group = create_player(attributes: { first_name: "Wrong", last_name: "Group" })
    target.create_profile!(birth_date: Date.new(2000, 1, 1), source_name: "test", last_synced_at: Time.current)
    same_group.create_profile!(birth_date: Date.new(2001, 1, 1), source_name: "test", last_synced_at: Time.current)
    wrong_group.create_profile!(birth_date: Date.new(1990, 1, 1), source_name: "test", last_synced_at: Time.current)
    create_player_position(player: target, position: outfield, attributes: { is_primary: true })
    create_player_position(player: same_group, position: outfield, attributes: { is_primary: true })
    create_player_position(player: wrong_group, position: infield, attributes: { is_primary: true })

    %w[avg obp ops].each_with_index do |name, index|
      stat_type = create_stat_type(name: name, label: name.upcase, category: "batting")
      [ target, same_group, wrong_group ].each_with_index do |candidate, candidate_index|
        create_player_season_stat(
          player: candidate,
          stat_type: stat_type,
          attributes: { season: 2026, value: 0.3 + index * 0.05 + candidate_index * 0.001, team: nil, scope_type: "combined", scope_key: "TOT" }
        )
      end
    end

    result = described_class.new(
      player: target,
      season: 2026,
      category: "batting",
      min_age: 20,
      max_age: 30,
      position_match: "same_type"
    ).result

    expect(result.fetch(:matches).map { |match| match.dig(:player, :id) }).to eq([ same_group.id ])
    expect(result.fetch(:controls)).to include(min_age: 20, max_age: 30, position_match: "same_type", target_age: 26)
  end

  it "returns no matches when the player lacks enough comparable metrics" do
    player = create_player
    avg = create_stat_type(name: "avg", label: "AVG", category: "batting")
    create_player_season_stat(player: player, stat_type: avg, attributes: { season: 2026, value: 0.275 })

    result = described_class.new(player: player, season: 2026, category: "batting").result

    expect(result.fetch(:matches)).to be_empty
  end
end
