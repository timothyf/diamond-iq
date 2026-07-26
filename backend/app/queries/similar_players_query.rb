class SimilarPlayersQuery
  DEFAULT_LIMIT = 6
  MIN_SHARED_METRICS = 3
  POSITION_MISMATCH_PENALTY = 0.35

  FEATURE_DEFINITIONS = {
    "batting" => [
      { key: "avg", label: "AVG", aliases: %w[avg AVG], kind: :rate },
      { key: "obp", label: "OBP", aliases: %w[obp OBP], kind: :rate },
      { key: "slg", label: "SLG", aliases: %w[slg SLG], kind: :rate },
      { key: "ops", label: "OPS", aliases: %w[ops OPS], kind: :rate },
      { key: "hr_rate", label: "HR / PA", numerator: %w[homeRuns HR], denominator: :batting_opportunities, scale: 100 },
      { key: "bb_rate", label: "BB / PA", numerator: %w[baseOnBalls BB], denominator: :batting_opportunities, scale: 100 },
      { key: "so_rate", label: "SO / PA", numerator: %w[strikeOuts SO], denominator: :batting_opportunities, scale: 100 },
      { key: "sb_rate", label: "SB / PA", numerator: %w[stolenBases SB], denominator: :batting_opportunities, scale: 100 }
    ],
    "pitching" => [
      { key: "era", label: "ERA", aliases: %w[ERA era], kind: :rate },
      { key: "whip", label: "WHIP", aliases: %w[whip WHIP], kind: :rate },
      { key: "k_per_9", label: "K/9", numerator: %w[strikeOuts SO], denominator: :innings, scale: 9 },
      { key: "bb_per_9", label: "BB/9", numerator: %w[baseOnBalls BB], denominator: :innings, scale: 9 },
      { key: "hr_per_9", label: "HR/9", numerator: %w[homeRuns HR], denominator: :innings, scale: 9 },
      { key: "opponent_avg", label: "Opponent AVG", aliases: %w[avg AVG], kind: :rate }
    ]
  }.freeze

  def initialize(player:, season:, category:, limit: DEFAULT_LIMIT)
    @player = player
    @season = season
    @category = category
    @limit = limit
  end

  def result
    return empty_result unless season.present? && FEATURE_DEFINITIONS.key?(category)

    target = profiles_by_player_id[player.id]
    return empty_result if target.blank?

    candidates = profiles_by_player_id.except(player.id).values
      .filter { |profile| shared_keys(target, profile).length >= MIN_SHARED_METRICS }
    return empty_result if candidates.empty?

    distributions = metric_distributions([ target, *candidates ])
    matches = candidates.filter_map { |candidate| scored_match(target, candidate, distributions) }
      .sort_by { |match| [ match.fetch(:distance), match.dig(:player, :full_name).to_s ] }
      .first(limit)
      .map { |match| match.except(:distance) }

    {
      season: season,
      category: category,
      methodology: "Standardized same-season statistical distance with a position-role adjustment.",
      matches: matches
    }
  end

  private

  attr_reader :player, :season, :category, :limit

  def empty_result
    { season: season, category: category, methodology: nil, matches: [] }
  end

  def profiles_by_player_id
    @profiles_by_player_id ||= rows.group_by(&:player_id).transform_values do |player_rows|
      candidate = player_rows.first.player
      {
        player: candidate,
        position: primary_position(candidate),
        metrics: build_metrics(player_rows)
      }
    end
  end

  def rows
    aliases = FEATURE_DEFINITIONS.fetch(category).flat_map do |definition|
      Array(definition[:aliases]) + Array(definition[:numerator])
    end
    aliases += %w[plateAppearances PA atBats AB baseOnBalls BB hitByPitch HBP sacFlies SF inningsPitched IP]

    PlayerSeasonStat
      .joins(:stat_type)
      .where(season: season, stat_types: { category: category, name: aliases.uniq })
      .where.not(scope_type: "league")
      .includes(:stat_type, player: [ :team, :profile, { player_positions: :position } ])
      .to_a
  end

  def build_metrics(player_rows)
    FEATURE_DEFINITIONS.fetch(category).to_h do |definition|
      value =
        if definition[:kind] == :rate
          rate_value(player_rows, definition.fetch(:aliases))
        else
          numerator = additive_value(player_rows, definition.fetch(:numerator))
          denominator = send(definition.fetch(:denominator), player_rows)
          denominator&.positive? && numerator ? (numerator / denominator * definition.fetch(:scale)).to_f : nil
        end

      [ definition.fetch(:key), value&.to_f ]
    end.compact
  end

  def batting_opportunities(player_rows)
    additive_value(player_rows, %w[plateAppearances PA]) ||
      begin
        components = [
          additive_value(player_rows, %w[atBats AB]),
          additive_value(player_rows, %w[baseOnBalls BB]),
          additive_value(player_rows, %w[hitByPitch HBP]),
          additive_value(player_rows, %w[sacFlies SF])
        ]
        components.compact.sum if components.first
      end
  end

  def innings(player_rows)
    value = additive_value(player_rows, %w[inningsPitched IP])
    return if value.nil?

    whole, partial = value.to_s.split(".", 2)
    whole.to_i + partial.to_i.clamp(0, 2) / 3.0
  end

  def additive_value(player_rows, aliases)
    matching = player_rows.select { |row| aliases.include?(row.stat_type.name) }
    combined = matching.find { |row| row.scope_type == "combined" }
    return combined.value.to_f if combined

    team_rows = matching.select { |row| row.scope_type == "team" }
    team_rows.presence&.sum { |row| row.value.to_f }
  end

  def rate_value(player_rows, aliases)
    matching = player_rows.select { |row| aliases.include?(row.stat_type.name) }
    (matching.find { |row| row.scope_type == "combined" } || matching.first)&.value&.to_f
  end

  def primary_position(candidate)
    assignments = candidate.player_positions
    assignment = assignments.find { |item| item.is_primary? && item.season == season } ||
      assignments.find { |item| item.is_primary? && item.season.nil? }
    position = assignment&.position
    return nil unless position

    {
      id: position.id,
      abbreviation: position.abbreviation,
      name: position.name,
      position_type: position.position_type
    }
  end

  def shared_keys(left, right)
    left.fetch(:metrics).keys & right.fetch(:metrics).keys
  end

  def metric_distributions(profiles)
    FEATURE_DEFINITIONS.fetch(category).to_h do |definition|
      key = definition.fetch(:key)
      values = profiles.filter_map { |profile| profile.dig(:metrics, key) }
      next [ key, { mean: nil, standard_deviation: nil } ] if values.empty?

      mean = values.sum / values.length.to_f
      variance = values.sum { |value| (value - mean)**2 } / values.length.to_f
      [ key, { mean: mean, standard_deviation: Math.sqrt(variance) } ]
    end
  end

  def scored_match(target, candidate, distributions)
    keys = shared_keys(target, candidate)
    differences = keys.filter_map do |key|
      standard_deviation = distributions.dig(key, :standard_deviation)
      next if standard_deviation.nil? || standard_deviation.zero?

      difference = ((target.dig(:metrics, key) - candidate.dig(:metrics, key)) / standard_deviation).abs
      { key: key, difference: difference }
    end
    return if differences.length < MIN_SHARED_METRICS

    distance = Math.sqrt(differences.sum { |item| item.fetch(:difference)**2 } / differences.length)
    same_position_type = target.dig(:position, :position_type).present? &&
      target.dig(:position, :position_type) == candidate.dig(:position, :position_type)
    distance += POSITION_MISMATCH_PENALTY unless same_position_type

    {
      distance: distance,
      similarity_score: (100 / (1 + distance)).round(1),
      shared_metric_count: differences.length,
      same_position_type: same_position_type,
      player: serialize_player(candidate.fetch(:player)),
      team: serialize_team(candidate.fetch(:player).team),
      position: candidate.fetch(:position),
      closest_metrics: closest_metrics(target, candidate, differences)
    }
  end

  def closest_metrics(target, candidate, differences)
    differences.sort_by { |item| item.fetch(:difference) }.first(3).map do |item|
      definition = FEATURE_DEFINITIONS.fetch(category).find { |feature| feature.fetch(:key) == item.fetch(:key) }
      {
        key: item.fetch(:key),
        label: definition.fetch(:label),
        target_value: target.dig(:metrics, item.fetch(:key)).round(3),
        candidate_value: candidate.dig(:metrics, item.fetch(:key)).round(3)
      }
    end
  end

  def serialize_player(candidate)
    {
      id: candidate.id,
      mlb_id: candidate.mlb_id,
      full_name: candidate.full_name,
      headshot_url: candidate.profile&.headshot_url
    }
  end

  def serialize_team(team)
    return nil unless team

    {
      id: team.id,
      mlb_id: team.mlb_id,
      name: team.name,
      abbreviation: team.abbreviation
    }
  end
end
