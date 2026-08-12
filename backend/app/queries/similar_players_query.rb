class SimilarPlayersQuery
  StatRow = Struct.new(:player_id, :season, :value, :scope_type, :stat_type_name)
  DEFAULT_LIMIT = 6
  MIN_SHARED_METRICS = 3
  POSITION_MISMATCH_PENALTY = 0.35
  POSITION_MATCH_MODES = %w[any same_type same_position].freeze
  COMPARISON_MODES = %w[season career].freeze

  FEATURE_DEFINITIONS = {
    "batting" => [
      { key: "avg", label: "AVG", aliases: %w[avg AVG], kind: :rate, weight: 0.10 },
      { key: "obp", label: "OBP", aliases: %w[obp OBP], kind: :rate, weight: 0.15 },
      { key: "slg", label: "SLG", aliases: %w[slg SLG], kind: :rate, weight: 0.15 },
      { key: "ops", label: "OPS", aliases: %w[ops OPS], kind: :rate, weight: 0.20 },
      { key: "hr_rate", label: "HR / PA", numerator: %w[homeRuns HR], denominator: :batting_opportunities, scale: 100, weight: 0.15 },
      { key: "bb_rate", label: "BB / PA", numerator: %w[baseOnBalls BB], denominator: :batting_opportunities, scale: 100, weight: 0.10 },
      { key: "so_rate", label: "SO / PA", numerator: %w[strikeOuts SO], denominator: :batting_opportunities, scale: 100, weight: 0.10 },
      { key: "sb_rate", label: "SB / PA", numerator: %w[stolenBases SB], denominator: :batting_opportunities, scale: 100, weight: 0.05 }
    ],
    "pitching" => [
      { key: "era", label: "ERA", aliases: %w[ERA era], kind: :rate, weight: 0.25 },
      { key: "whip", label: "WHIP", aliases: %w[whip WHIP], kind: :rate, weight: 0.20 },
      { key: "k_per_9", label: "K/9", numerator: %w[strikeOuts SO], denominator: :innings, scale: 9, weight: 0.20 },
      { key: "bb_per_9", label: "BB/9", numerator: %w[baseOnBalls BB], denominator: :innings, scale: 9, weight: 0.15 },
      { key: "hr_per_9", label: "HR/9", numerator: %w[homeRuns HR], denominator: :innings, scale: 9, weight: 0.15 },
      { key: "opponent_avg", label: "Opponent AVG", aliases: %w[avg AVG], kind: :rate, weight: 0.05 }
    ]
  }.freeze

  def initialize(player:, season:, category:, limit: DEFAULT_LIMIT, mode: "season", min_age: nil, max_age: nil, position_match: "any")
    @player = player
    @season = Integer(season, exception: false)
    @category = category
    @limit = limit
    @mode = COMPARISON_MODES.include?(mode.to_s) ? mode.to_s : "season"
    @min_age = Integer(min_age, exception: false)
    @max_age = Integer(max_age, exception: false)
    @position_match = POSITION_MATCH_MODES.include?(position_match.to_s) ? position_match.to_s : "any"
  end

  def result
    return empty_result unless season.present? && FEATURE_DEFINITIONS.key?(category)

    target = profiles_by_player_id[player.id]
    return empty_result if target.blank?

    candidates = profiles_by_player_id.except(player.id).values
      .filter { |profile| age_matches?(profile) && position_matches?(target, profile) }
      .filter { |profile| shared_keys(target, profile).length >= MIN_SHARED_METRICS }
    return empty_result(target) if candidates.empty?

    distributions = metric_distributions([ target, *candidates ])
    matches = candidates.filter_map { |candidate| scored_match(target, candidate, distributions) }
      .sort_by { |match| [ match.fetch(:distance), match.dig(:player, :full_name).to_s ] }
      .first(limit)
      .map { |match| match.except(:distance) }

    {
      season: season,
      category: category,
      mode: mode,
      methodology: methodology,
      model_metrics: model_metrics,
      position_mismatch_penalty: POSITION_MISMATCH_PENALTY,
      controls: controls_payload(target),
      matches: matches
    }
  end

  private

  attr_reader :player, :season, :category, :limit, :mode, :min_age, :max_age, :position_match

  def empty_result(target = nil)
    {
      season: season,
      category: category,
      mode: mode,
      methodology: nil,
      model_metrics: FEATURE_DEFINITIONS.fetch(category, []).map { |definition| serialize_model_metric(definition) },
      position_mismatch_penalty: POSITION_MISMATCH_PENALTY,
      controls: controls_payload(target),
      matches: []
    }
  end

  def profiles_by_player_id
    @profiles_by_player_id ||= rows.group_by(&:player_id).transform_values do |player_rows|
      candidate = players_by_id.fetch(player_rows.first.player_id)
      {
        player: candidate,
        position: primary_position(candidate),
        age: age_for(candidate),
        metrics: build_metrics(player_rows)
      }
    end
  end

  def players_by_id
    @players_by_id ||= Player.where(id: rows.map(&:player_id).uniq)
      .includes(:team, :profile, player_positions: :position)
      .index_by(&:id)
  end

  def available_seasons
    @available_seasons ||= PlayerSeasonStat.joins(:stat_type)
      .where(player: player, stat_types: { category: category })
      .distinct
      .order(season: :desc)
      .pluck(:season)
  end

  def age_for(candidate)
    on = mode == "career" ? Date.current : Date.new(season, 7, 1)
    candidate.profile&.age(on: on)
  end

  def age_matches?(profile)
    age = profile.fetch(:age)
    return false if (min_age.present? || max_age.present?) && age.nil?
    return false if min_age.present? && age < min_age
    return false if max_age.present? && age > max_age

    true
  end

  def position_matches?(target, candidate)
    return true if position_match == "any"

    target_position = target.fetch(:position)
    candidate_position = candidate.fetch(:position)
    return false if target_position.blank? || candidate_position.blank?

    if position_match == "same_position"
      target_position.fetch(:id) == candidate_position.fetch(:id)
    else
      target_position.fetch(:position_type) == candidate_position.fetch(:position_type)
    end
  end

  def controls_payload(target = nil)
    {
      available_seasons: available_seasons,
      mode: mode,
      selected_season: season,
      min_age: min_age,
      max_age: max_age,
      target_age: target&.fetch(:age, nil),
      position_match: position_match,
      position_options: [
        { value: "any", label: "Any position" },
        { value: "same_type", label: "Same position group" },
        { value: "same_position", label: "Same primary position" }
      ]
    }
  end

  def rows
    aliases = FEATURE_DEFINITIONS.fetch(category).flat_map do |definition|
      Array(definition[:aliases]) + Array(definition[:numerator])
    end
    aliases += %w[plateAppearances PA atBats AB baseOnBalls BB hitByPitch HBP sacFlies SF inningsPitched IP]

    scope = PlayerSeasonStat
      .joins(:stat_type)
      .where(stat_types: { category: category, name: aliases.uniq })
      .where.not(scope_type: "league")
    scope = if mode == "season"
      scope.where(season: season)
    else
      scope.where(player_id: career_candidate_player_ids)
    end
    scope.pluck(:player_id, :season, :value, :scope_type, "stat_types.name").map do |attributes|
      StatRow.new(*attributes)
    end
  end

  def career_candidate_player_ids
    @career_candidate_player_ids ||= PlayerSeasonStat.joins(:stat_type)
      .where(season: season, stat_types: { category: category })
      .where.not(scope_type: "league")
      .distinct
      .pluck(:player_id)
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
    if mode == "career"
      values = player_rows.group_by(&:season).values.filter_map { |season_rows| season_additive_value(season_rows, aliases) }
      return values.sum if values.any?
      return nil
    end

    season_additive_value(player_rows, aliases)
  end

  def season_additive_value(player_rows, aliases)
    matching = player_rows.select { |row| aliases.include?(row.stat_type_name) }
    combined = matching.find { |row| row.scope_type == "combined" }
    return combined.value.to_f if combined

    team_rows = matching.select { |row| row.scope_type == "team" }
    team_rows.presence&.sum { |row| row.value.to_f }
  end

  def rate_value(player_rows, aliases)
    if mode == "career"
      weighted = player_rows.group_by(&:season).values.filter_map do |season_rows|
        value = season_rate_value(season_rows, aliases)
        weight = category == "pitching" ? innings(season_rows) : batting_opportunities(season_rows)
        next if value.nil? || weight.nil? || !weight.positive?

        [ value, weight ]
      end
      return weighted.sum { |value, weight| value * weight } / weighted.sum { |_value, weight| weight } if weighted.any?
    end

    season_rate_value(player_rows, aliases)
  end

  def season_rate_value(player_rows, aliases)
    matching = player_rows.select { |row| aliases.include?(row.stat_type_name) }
    (matching.find { |row| row.scope_type == "combined" } || matching.first)&.value&.to_f
  end

  def primary_position(candidate)
    assignments = candidate.player_positions
    assignment = if mode == "career"
      assignments.select(&:is_primary?).max_by { |item| item.season || 0 }
    else
      assignments.find { |item| item.is_primary? && item.season == season }
    end
    assignment ||=
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
      definition = feature_definition(key)
      { key: key, difference: difference, weight: definition.fetch(:weight) }
    end
    return if differences.length < MIN_SHARED_METRICS

    available_weight = differences.sum { |item| item.fetch(:weight) }
    distance = Math.sqrt(
      differences.sum { |item| item.fetch(:weight) * item.fetch(:difference)**2 } / available_weight
    )
    same_position_type = target.dig(:position, :position_type).present? &&
      target.dig(:position, :position_type) == candidate.dig(:position, :position_type)
    distance += POSITION_MISMATCH_PENALTY unless same_position_type

    {
      distance: distance,
      similarity_score: (100 / (1 + distance)).round(1),
      shared_metric_count: differences.length,
      same_position_type: same_position_type,
      age: candidate.fetch(:age),
      player: serialize_player(candidate.fetch(:player)),
      team: serialize_team(candidate.fetch(:player).team),
      position: candidate.fetch(:position),
      why_similar: why_similar(candidate, differences, same_position_type),
      metrics_used: comparison_metrics(target, candidate, differences, available_weight),
      closest_metrics: closest_metrics(target, candidate, differences, available_weight)
    }
  end

  def closest_metrics(target, candidate, differences, available_weight)
    differences.sort_by { |item| item.fetch(:difference) }.first(3).map do |item|
      serialize_comparison_metric(target, candidate, item, available_weight)
    end
  end

  def comparison_metrics(target, candidate, differences, available_weight)
    differences.map { |item| serialize_comparison_metric(target, candidate, item, available_weight) }
      .sort_by { |metric| -metric.fetch(:normalized_weight) }
  end

  def serialize_comparison_metric(target, candidate, item, available_weight)
    definition = feature_definition(item.fetch(:key))
    {
      key: item.fetch(:key),
      label: definition.fetch(:label),
      target_value: target.dig(:metrics, item.fetch(:key)).round(3),
      candidate_value: candidate.dig(:metrics, item.fetch(:key)).round(3),
      weight: item.fetch(:weight),
      normalized_weight: (item.fetch(:weight) / available_weight).round(4),
      standardized_difference: item.fetch(:difference).round(3)
    }
  end

  def why_similar(candidate, differences, same_position_type)
    closest_labels = differences.sort_by { |item| item.fetch(:difference) }.first(3)
      .map { |item| feature_definition(item.fetch(:key)).fetch(:label) }
    reasons = [ "Closest statistical alignment: #{closest_labels.to_sentence}." ]
    if same_position_type
      reasons << "Same position group: #{candidate.dig(:position, :position_type).to_s.humanize}."
    else
      reasons << "Different position group; a #{POSITION_MISMATCH_PENALTY} distance penalty was applied."
    end
    reasons
  end

  def methodology
    period = if mode == "career"
      "career statistics with playing-time-weighted rates among players active in the selected season"
    else
      "same-season statistics"
    end
    "Weighted standardized distance using #{period} and a position-role adjustment. Available metric weights are normalized for each comparison."
  end

  def model_metrics
    FEATURE_DEFINITIONS.fetch(category).map { |definition| serialize_model_metric(definition) }
  end

  def serialize_model_metric(definition)
    { key: definition.fetch(:key), label: definition.fetch(:label), weight: definition.fetch(:weight) }
  end

  def feature_definition(key)
    FEATURE_DEFINITIONS.fetch(category).find { |definition| definition.fetch(:key) == key }
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
