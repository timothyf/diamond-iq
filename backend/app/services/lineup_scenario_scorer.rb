class LineupScenarioScorer
  COMPONENT_WEIGHTS = {
    opponent: 0.2,
    park: 0.15,
    platoon: 0.25,
    recent_performance: 0.2,
    reliability: 0.2
  }.freeze

  def self.call(scenario:, inputs:)
    new(scenario: scenario, inputs: inputs).result
  end

  def initialize(scenario:, inputs:)
    @scenario = scenario
    @inputs = inputs.to_h.stringify_keys
  end

  def result
    components = {
      opponent: score_opponent,
      park: score_park,
      platoon: score_platoon,
      recent_performance: numeric_input("recent_performance", 50),
      reliability: numeric_input("reliability", 50)
    }.transform_values { |value| value.round(1) }

    {
      total_score: weighted_score(components),
      score_breakdown: components.merge(weights: COMPONENT_WEIGHTS)
    }
  end

  private

  attr_reader :scenario, :inputs

  def score_opponent
    100 - numeric_input("opponent_strength", 50)
  end

  def score_park
    raw_input("park_factor", 100).clamp(80, 120) - 80
  end

  def score_platoon
    pitcher_hand = inputs["pitcher_hand"].to_s.upcase
    return 50 unless %w[L R].include?(pitcher_hand)

    bats = scenario.entries.includes(player: :profile).filter_map { |entry| entry.player.profile&.bats&.upcase }
    return 50 if bats.empty?

    favorable = bats.count { |hand| hand != pitcher_hand && hand != "S" } + bats.count { |hand| hand == "S" }
    (50 + ((favorable.to_f / bats.length) * 50)).clamp(0, 100)
  end

  def numeric_input(key, fallback)
    value = raw_input(key, fallback)
    value.finite? ? value.clamp(0, 100) : fallback
  rescue ArgumentError, TypeError
    fallback
  end

  def raw_input(key, fallback)
    Float(inputs.key?(key) ? inputs[key] : fallback)
  rescue ArgumentError, TypeError
    fallback
  end

  def weighted_score(components)
    COMPONENT_WEIGHTS.sum { |key, weight| components.fetch(key) * weight }.round(2)
  end
end
