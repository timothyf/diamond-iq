class LineupDecisionSupport
  DEFAULT_WEIGHTS = { production: 0.45, platoon: 0.25, recent: 0.15, reliability: 0.15 }.freeze
  POSITIONS = LineupScenarioEntry::DEFENSIVE_POSITIONS.freeze
  PITCHER_CODES = %w[P SP RP].freeze

  def self.call(team:, season:, on: Date.current, constraints: {}, weights: {}, alternatives: 3)
    new(team: team, season: season, on: on, constraints: constraints, weights: weights, alternatives: alternatives).call
  end

  def initialize(team:, season:, on:, constraints:, weights:, alternatives:)
    @team = team
    @season = season
    @on = on
    @constraints = constraints.to_h.stringify_keys
    @weights = normalize_weights(weights)
    @alternative_count = [[ alternatives.to_i, 0 ].max, 5].min
  end

  def call
    pool = eligible_players
    required_ids = ids("required_starter_ids")
    locked_ids = ids("locked_player_ids")
    selected = (pool.select { |player| required_ids.include?(player.id) || locked_ids.include?(player.id) } + pool)
      .uniq(&:id)
      .sort_by { |player| -player_score(player) }
      .first(9)
    missing = required_ids - selected.map(&:id)
    return { errors: [ "Required starters are unavailable: #{missing.join(', ')}" ] } if missing.any?
    return { errors: [ "At least nine eligible players are required to build a lineup." ] } if selected.length < 9

    recommended = build_order(selected)
    alternatives = build_alternatives(selected, recommended)
    {
      constraints: normalized_constraints,
      weights: @weights,
      recommended: serialize_lineup(recommended),
      alternatives: alternatives.map { |lineup| serialize_lineup(lineup) },
      explanation: explain(recommended)
    }
  end

  private

  attr_reader :team, :season, :on, :constraints, :weights

  def eligible_players
    excluded = ids("excluded_player_ids") | ids("unavailable_player_ids")
    memberships = team.team_memberships.active_on(on).where(roster_status: "active").includes(player: :profile)
    memberships.filter_map do |membership|
      player = membership.player
      next if pitcher?(membership, player)
      next if excluded.include?(player.id) || resting?(player)

      player
    end.uniq(&:id)
  end

  def pitcher?(membership, player)
    return true if PITCHER_CODES.include?(membership.primary_position.to_s.upcase)

    player.primary_position(season: season)&.position_type.to_s == "pitcher"
  end

  def build_order(players)
    locked_order = constraints.fetch("locked_batting_order", {}).to_h.transform_keys { |key| Integer(key) rescue key.to_i }
    ordered = Array.new(9)
    players.each do |player|
      slot = locked_order[player.id] || locked_order[player.id.to_s]
      ordered[slot.to_i - 1] = player if slot.to_i.between?(1, 9)
    end
    remaining = players.reject { |player| ordered.include?(player) }.sort_by { |player| -player_score(player) }
    ordered.map! { |player| player || remaining.shift }
    ordered
  end

  def build_alternatives(players, recommended)
    alternatives = []
    (1..@alternative_count).each do |index|
      lineup = recommended.dup
      movable = movable_slots(lineup)
      next if movable.length < 2
      first, second = movable.rotate(index - 1).first(2)
      lineup[first], lineup[second] = lineup[second], lineup[first]
      alternatives << lineup
    end
    alternatives
  end

  def movable_slots(lineup)
    locked = constraints.fetch("locked_batting_order", {}).to_h.values.map { |slot| slot.to_i - 1 }
    (0...lineup.length).to_a.reject { |slot| locked.include?(slot) }
  end

  def serialize_lineup(lineup)
    assignments = position_assignments(lineup)
    lineup.each_with_index.map do |player, index|
      { player_id: player.id, player_name: player.full_name, batting_slot: index + 1, defensive_position: assignments.fetch(player.id) }
    end
  end

  def position_assignments(lineup)
    assignments = {}
    used = []
    lineup.each do |player|
      preferred = player.primary_position(season: season)&.abbreviation.to_s.upcase
      next unless POSITIONS.include?(preferred) && !used.include?(preferred)

      assignments[player.id] = preferred
      used << preferred
    end
    (POSITIONS - used).each do |position|
      player = lineup.find { |candidate| !assignments.key?(candidate.id) }
      break unless player

      assignments[player.id] = position
    end
    assignments
  end

  def player_score(player)
    production = latest_stat(player, %w[OPS OBP SLG AVG])
    production = production.to_f <= 1 ? production.to_f * 100 : production.to_f
    platoon = platoon_score(player)
    recent = 50.0
    reliability = 50.0
    (production.clamp(0, 100) * weights.fetch("production") + platoon * weights.fetch("platoon") + recent * weights.fetch("recent") + reliability * weights.fetch("reliability"))
  end

  def latest_stat(player, names)
    stat = player.player_season_stats.includes(:stat_type).where(season: season).sort_by { |row| names.index(row.stat_type.name.to_s.upcase) || 999 }.first
    stat&.value || 50
  end

  def platoon_score(player)
    hand = player.profile&.bats.to_s.upcase
    pitcher_hand = constraints["pitcher_hand"].to_s.upcase
    return 50 unless %w[L R].include?(pitcher_hand)
    return 75 if hand == "S" || (pitcher_hand == "R" && hand == "L") || (pitcher_hand == "L" && hand == "R")

    35
  end

  def explain(lineup)
    [
      "Recommended order prioritizes production (#{percentage(weights.fetch('production'))}), platoon fit (#{percentage(weights.fetch('platoon'))}), recent form (#{percentage(weights.fetch('recent'))}), and reliability (#{percentage(weights.fetch('reliability'))}).",
      locked_explanation,
      "#{lineup.length} eligible starters satisfy the availability and exclusion rules."
    ].compact
  end

  def locked_explanation
    locked = constraints.fetch("locked_batting_order", {}).to_h
    return nil if locked.empty?

    "Locked batting slots preserved: #{locked.sort_by { |_, slot| slot.to_i }.map { |player_id, slot| "##{slot} (player #{player_id})" }.join(', ')}."
  end

  def normalized_constraints
    constraints.merge(
      "locked_player_ids" => ids("locked_player_ids"),
      "excluded_player_ids" => ids("excluded_player_ids"),
      "required_starter_ids" => ids("required_starter_ids"),
      "unavailable_player_ids" => ids("unavailable_player_ids")
    )
  end

  def resting?(player)
    restriction = constraints.fetch("rest_restrictions", {}).to_h[player.id.to_s] || constraints.fetch("rest_restrictions", {}).to_h[player.id]
    restriction.present? && Date.iso8601(restriction.to_s) > on
  rescue Date::Error
    false
  end

  def ids(key)
    Array(constraints[key]).filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def normalize_weights(values)
    parsed = DEFAULT_WEIGHTS.merge(values.to_h.stringify_keys.slice(*DEFAULT_WEIGHTS.keys).transform_values { |value| Float(value) rescue nil }.compact)
    total = parsed.values.sum
    normalized = total.positive? ? parsed.transform_values { |value| (value / total).round(4) } : DEFAULT_WEIGHTS
    normalized.stringify_keys
  end

  def percentage(value)
    "#{(value.to_f * 100).round}%"
  end
end
