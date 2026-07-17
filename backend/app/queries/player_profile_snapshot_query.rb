class PlayerProfileSnapshotQuery
  PITCH_SAMPLE_SIZE = 100
  SEASON_CATEGORIES = %w[batting pitching].freeze
  BATTING_RATE_KEYS = %w[avg obp slg ops].freeze
  PITCHING_RATE_KEYS = %w[ERA whip avg].freeze

  def initialize(player:, on: Date.current, analysis_range: nil)
    @player = player
    @on = on
    @analysis_range = analysis_range || PlayerAnalysisRange.resolve(player: player)
  end

  def result
    {
      season_overview: season_overview,
      career_overview: career_overview,
      current_membership: serialize_membership(current_membership),
      team_history: memberships.map { |membership| serialize_membership(membership) },
      recent_pitch_indicators: recent_pitch_indicators,
      contextual_benchmarks: PlayerBenchmarkSnapshotQuery.new(
        player: player,
        start_date: analysis_range.start_date,
        end_date: analysis_range.end_date
      ).result,
      analysis: PlayerTrendQuery.new(player: player, analysis_range: analysis_range).result,
      source_metadata: source_metadata
    }
  end

  private

  attr_reader :player, :on, :analysis_range

  def season_overview
    return empty_season_overview if latest_season.nil?

    available_categories = season_rows.map { |row| row.stat_type.category }.uniq & SEASON_CATEGORIES
    category = available_categories.include?(preferred_category) ? preferred_category : available_categories.first

    {
      season: latest_season,
      category: category,
      preferred_category: preferred_category,
      stats: category.present? ? serialized_season_stats(category) : []
    }
  end

  def empty_season_overview
    { season: nil, category: preferred_category, preferred_category: preferred_category, stats: [] }
  end

  def career_overview
    category = career_category
    rows = career_rows(category)
    return empty_career_overview if rows.empty?

    seasons = rows.map(&:season).uniq.sort

    {
      category: category,
      preferred_category: preferred_category,
      first_season: seasons.first,
      last_season: seasons.last,
      season_count: seasons.length,
      columns: career_columns(category),
      seasons: serialized_career_seasons(category),
      stats: serialized_career_stats(category)
    }
  end

  def empty_career_overview
    {
      category: preferred_category,
      preferred_category: preferred_category,
      first_season: nil,
      last_season: nil,
      season_count: 0,
      columns: [],
      seasons: [],
      stats: []
    }
  end

  def career_columns(category)
    available_keys = serialized_career_stats(category).pluck(:key)

    PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category).filter_map do |definition|
      next unless available_keys.include?(definition.fetch(:key))

      { key: definition.fetch(:key), label: definition.fetch(:label) }
    end
  end

  def serialized_career_seasons(category)
    career_rows_by_season(category).sort.map do |season, rows|
      {
        season: season,
        teams: rows.filter_map(&:team).uniq(&:id).map { |team| serialize_team(team) },
        stats: serialized_stats_for_season(category, rows)
      }
    end
  end

  def serialized_stats_for_season(category, rows)
    PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category).filter_map do |definition|
      value = season_stat_value(category, definition, rows)
      next if value.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: format_career_value(category, definition.fetch(:key), value)
      }
    end
  end

  def season_stat_value(category, definition, rows)
    key = definition.fetch(:key)
    aliases = Array(definition.fetch(:aliases))

    if category == "pitching" && key == "inningsPitched"
      innings = season_additive_value(rows, aliases)
      return innings.nil? ? nil : format_innings(innings_to_outs(innings))
    end
    return season_batting_average(rows) if category == "batting" && key == "avg"
    return season_batting_slugging(rows) if category == "batting" && key == "slg"
    return season_batting_ops(rows) if category == "batting" && key == "ops"
    return season_weighted_rate(rows, aliases, %w[atBats AB]) if category == "batting" && key == "obp"
    return season_pitching_era(rows) if category == "pitching" && key == "ERA"
    return season_pitching_whip(rows) if category == "pitching" && key == "whip"
    if category == "pitching" && key == "avg"
      return season_weighted_rate(rows, aliases, %w[inningsPitched IP], innings_weight: true)
    end

    season_additive_value(rows, aliases)
  end

  def season_batting_average(rows)
    divide(
      season_additive_value(rows, %w[hits H]),
      season_additive_value(rows, %w[atBats AB])
    ) || season_weighted_rate(rows, %w[avg AVG], %w[atBats AB])
  end

  def season_batting_slugging(rows)
    hits = season_additive_value(rows, %w[hits H])
    at_bats = season_additive_value(rows, %w[atBats AB])
    doubles = season_additive_value(rows, %w[doubles 2B]) || 0.to_d
    triples = season_additive_value(rows, %w[triples 3B]) || 0.to_d
    home_runs = season_additive_value(rows, %w[homeRuns HR]) || 0.to_d
    return season_weighted_rate(rows, %w[slg SLG], %w[atBats AB]) if hits.nil? || at_bats.nil?

    divide(hits + doubles + (triples * 2) + (home_runs * 3), at_bats)
  end

  def season_batting_ops(rows)
    obp = season_weighted_rate(rows, %w[obp OBP], %w[atBats AB])
    slg = season_batting_slugging(rows)
    return season_weighted_rate(rows, %w[ops OPS], %w[atBats AB]) if obp.nil? || slg.nil?

    obp + slg
  end

  def season_pitching_era(rows)
    earned_runs = season_additive_value(rows, %w[ER earnedRuns])
    innings_value = season_additive_value(rows, %w[inningsPitched IP])
    innings = innings_as_decimal(innings_to_outs(innings_value)) if innings_value.present?
    return season_weighted_rate(rows, %w[ERA era], %w[inningsPitched IP], innings_weight: true) if earned_runs.nil?

    divide(earned_runs * 9, innings)
  end

  def season_pitching_whip(rows)
    hits = season_additive_value(rows, %w[hits H])
    walks = season_additive_value(rows, %w[baseOnBalls BB])
    innings_value = season_additive_value(rows, %w[inningsPitched IP])
    innings = innings_as_decimal(innings_to_outs(innings_value)) if innings_value.present?
    if hits.nil? || walks.nil?
      return season_weighted_rate(rows, %w[whip WHIP], %w[inningsPitched IP], innings_weight: true)
    end

    divide(hits + walks, innings)
  end

  def season_weighted_rate(rows, rate_aliases, weight_aliases, innings_weight: false)
    rate_rows = rows_for_preferred_alias(rows, rate_aliases)
    return if rate_rows.empty?

    combined = rate_rows.select { |row| row.scope_type == "combined" }.max_by(&:updated_at)
    return combined.value if combined.present?

    weighted_values = rate_rows.filter_map do |rate_row|
      matching_rows = rows.select do |row|
        row.scope_type == rate_row.scope_type && row.scope_key == rate_row.scope_key && row.team_id == rate_row.team_id
      end
      weight = season_additive_value(matching_rows, weight_aliases)
      next if weight.nil?

      numeric_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      next unless numeric_weight&.positive?

      [ rate_row.value, numeric_weight ]
    end
    return best_stat_row_from(rows, rate_aliases)&.value if weighted_values.empty?

    numerator = weighted_values.sum(0.to_d) { |value, weight| value * weight }
    denominator = weighted_values.sum(0.to_d) { |_value, weight| weight }
    divide(numerator, denominator)
  end

  def career_category
    available_categories = all_season_rows.map { |row| row.stat_type.category }.uniq & SEASON_CATEGORIES
    available_categories.include?(preferred_category) ? preferred_category : available_categories.first || preferred_category
  end

  def serialized_career_stats(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category)

    definitions.filter_map do |definition|
      value = career_stat_value(category, definition)
      next if value.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: format_career_value(category, definition.fetch(:key), value)
      }
    end
  end

  def career_stat_value(category, definition)
    key = definition.fetch(:key)
    aliases = Array(definition.fetch(:aliases))

    return format_innings(career_innings_outs) if category == "pitching" && key == "inningsPitched"
    return batting_average if category == "batting" && key == "avg"
    return batting_slugging if category == "batting" && key == "slg"
    return batting_ops if category == "batting" && key == "ops"
    return weighted_career_rate(category, aliases, %w[atBats AB]) if category == "batting" && key == "obp"
    return pitching_era if category == "pitching" && key == "ERA"
    return pitching_whip if category == "pitching" && key == "whip"
    return weighted_career_rate(category, aliases, %w[inningsPitched IP], innings_weight: true) if category == "pitching" && key == "avg"

    additive_career_value(category, aliases)
  end

  def batting_average
    divide(
      additive_career_value("batting", %w[hits H]),
      additive_career_value("batting", %w[atBats AB])
    ) || weighted_career_rate("batting", %w[avg AVG], %w[atBats AB])
  end

  def batting_slugging
    hits = additive_career_value("batting", %w[hits H])
    at_bats = additive_career_value("batting", %w[atBats AB])
    doubles = additive_career_value("batting", %w[doubles 2B]) || 0.to_d
    triples = additive_career_value("batting", %w[triples 3B]) || 0.to_d
    home_runs = additive_career_value("batting", %w[homeRuns HR]) || 0.to_d
    return weighted_career_rate("batting", %w[slg SLG], %w[atBats AB]) if hits.nil? || at_bats.nil?

    total_bases = hits + doubles + (triples * 2) + (home_runs * 3)
    divide(total_bases, at_bats)
  end

  def batting_ops
    obp = weighted_career_rate("batting", %w[obp OBP], %w[atBats AB])
    slg = batting_slugging
    return weighted_career_rate("batting", %w[ops OPS], %w[atBats AB]) if obp.nil? || slg.nil?

    obp + slg
  end

  def pitching_era
    earned_runs = additive_career_value("pitching", %w[ER earnedRuns])
    innings = innings_as_decimal(career_innings_outs)
    return weighted_career_rate("pitching", %w[ERA era], %w[inningsPitched IP], innings_weight: true) if earned_runs.nil?

    divide(earned_runs * 9, innings)
  end

  def pitching_whip
    hits = additive_career_value("pitching", %w[hits H])
    walks = additive_career_value("pitching", %w[baseOnBalls BB])
    innings = innings_as_decimal(career_innings_outs)
    if hits.nil? || walks.nil?
      return weighted_career_rate("pitching", %w[whip WHIP], %w[inningsPitched IP], innings_weight: true)
    end

    divide(hits + walks, innings)
  end

  def additive_career_value(category, aliases)
    values = career_rows_by_season(category).values.filter_map do |rows|
      season_additive_value(rows, aliases)
    end
    return nil if values.empty?

    values.sum(0.to_d)
  end

  def season_additive_value(rows, aliases)
    candidates = rows_for_preferred_alias(rows, aliases)
    return if candidates.empty?

    combined = candidates.select { |row| row.scope_type == "combined" }.max_by(&:updated_at)
    return combined.value if combined.present?

    team_rows = candidates.select { |row| row.scope_type == "team" }
    return team_rows.sum(0.to_d, &:value) if team_rows.any?

    candidates.min_by { |row| [ scope_priority(row), -row.updated_at.to_f ] }.value
  end

  def weighted_career_rate(category, rate_aliases, weight_aliases, innings_weight: false)
    weighted_values = career_rows_by_season(category).values.filter_map do |rows|
      rate_row = best_stat_row_from(rows, rate_aliases)
      weight = season_additive_value(rows, weight_aliases)
      next if rate_row.nil? || weight.nil?

      numeric_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      next unless numeric_weight&.positive?

      [ rate_row.value, numeric_weight ]
    end
    return nil if weighted_values.empty?

    numerator = weighted_values.sum(0.to_d) { |value, weight| value * weight }
    denominator = weighted_values.sum(0.to_d) { |_value, weight| weight }
    divide(numerator, denominator)
  end

  def career_innings_outs
    values = career_rows_by_season("pitching").values.filter_map do |rows|
      season_additive_value(rows, %w[inningsPitched IP])
    end
    return if values.empty?

    values.sum { |value| innings_to_outs(value) }
  end

  def innings_to_outs(value)
    whole_innings = value.floor
    partial_outs = ((value - whole_innings) * 10).round.to_i.clamp(0, 2)
    (whole_innings * 3) + partial_outs
  end

  def innings_as_decimal(outs)
    return if outs.nil? || outs.zero?

    outs.to_d / 3
  end

  def format_innings(outs)
    return if outs.nil?

    "#{outs / 3}.#{outs % 3}"
  end

  def divide(numerator, denominator)
    return if numerator.nil? || denominator.nil? || denominator.zero?

    numerator.to_d / denominator.to_d
  end

  def format_career_value(category, key, value)
    return value if value.is_a?(String)
    return format("%.3f", value) if category == "batting" && BATTING_RATE_KEYS.include?(key)
    return format("%.2f", value) if category == "pitching" && %w[ERA whip].include?(key)
    return format("%.3f", value) if category == "pitching" && PITCHING_RATE_KEYS.include?(key)

    decimal = value.to_d
    decimal.frac.zero? ? decimal.to_i.to_s : decimal.to_s("F")
  end

  def latest_season
    @latest_season ||= player.player_season_stats.maximum(:season)
  end

  def season_rows
    @season_rows ||= all_season_rows.select { |row| row.season == latest_season }
  end

  def all_season_rows
    @all_season_rows ||= player.player_season_stats.includes(:stat_type, :team).to_a
  end

  def career_rows(category)
    all_season_rows.select { |row| row.stat_type.category == category }
  end

  def career_rows_by_season(category)
    @career_rows_by_season ||= {}
    @career_rows_by_season[category] ||= career_rows(category).group_by(&:season)
  end

  def serialized_season_stats(category)
    definitions = PlayerSeasonStatsLeaderboardQuery::COLUMN_DEFINITIONS_BY_CATEGORY.fetch(category)

    definitions.filter_map do |definition|
      row = best_stat_row(category, Array(definition.fetch(:aliases)))
      next if row.nil?

      {
        key: definition.fetch(:key),
        label: definition.fetch(:label),
        value: row.value.to_s("F"),
        scope_type: row.scope_type,
        scope_key: row.scope_key,
        team: serialize_team(row.team),
        updated_at: row.updated_at
      }
    end
  end

  def best_stat_row(category, aliases)
    best_stat_row_from(
      season_rows.select { |row| row.stat_type.category == category },
      aliases
    )
  end

  def best_stat_row_from(rows, aliases)
    rows_for_preferred_alias(rows, aliases)
      .min_by { |row| [ scope_priority(row), -row.updated_at.to_f ] }
  end

  def rows_for_preferred_alias(rows, aliases)
    aliases.each do |alias_name|
      matching_rows = rows.select { |row| row.stat_type.name == alias_name }
      return matching_rows if matching_rows.any?
    end

    []
  end

  def scope_priority(row)
    return 0 if row.scope_type == "combined"
    return 1 if row.scope_type == "team" && row.team_id == player.team_id
    return 2 if row.scope_type == "team"

    3
  end

  def preferred_category
    @preferred_category ||= begin
      position_type = player.primary_position&.position_type
      %w[pitcher two_way].include?(position_type) ? "pitching" : "batting"
    end
  end

  def memberships
    @memberships ||= player.team_memberships
      .includes(:team)
      .order(starts_on: :desc, id: :desc)
      .to_a
  end

  def current_membership
    @current_membership ||= memberships
      .select { |membership| membership.starts_on <= on && (membership.ends_on.nil? || membership.ends_on >= on) }
      .min_by do |membership|
        [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ]
      end
  end

  def serialize_membership(membership)
    return nil if membership.nil?

    {
      id: membership.id,
      team: serialize_team(membership.team),
      starts_on: membership.starts_on,
      ends_on: membership.ends_on,
      current: membership == current_membership,
      roster_status: membership.roster_status,
      injured: membership.injured?,
      jersey_number: membership.jersey_number,
      primary_position: membership.primary_position,
      secondary_positions: membership.secondary_positions,
      source_name: membership.source_name,
      source_status_code: membership.source_status_code,
      source_status_description: membership.source_status_description,
      last_synced_at: membership.last_synced_at
    }
  end

  def serialize_team(team)
    return nil if team.nil?

    {
      id: team.id,
      mlb_id: team.mlb_id,
      name: team.name,
      abbreviation: team.abbreviation,
      team_name: team.team_name,
      location_name: team.location_name,
      short_name: team.short_name
    }
  end

  def recent_pitch_indicators
    {
      sample_size: PITCH_SAMPLE_SIZE,
      primary_role: preferred_category == "pitching" ? "pitcher" : "batter",
      pitching: pitching_indicators,
      batting: batting_indicators
    }
  end

  def pitching_indicators
    rows = recent_pitcher_rows
    velocities = numeric_values(rows, :release_speed)
    spin_rates = numeric_values(rows, :release_spin_rate)

    {
      pitch_count: rows.length,
      game_count: rows.map(&:game_pk).compact.uniq.length,
      latest_game_date: rows.filter_map(&:game_date).max,
      average_velocity: average(velocities),
      max_velocity: rounded(velocities.max),
      average_spin_rate: average(spin_rates),
      strike_percentage: percentage(rows.count { |row| %w[S X].include?(row.type) }, rows.length)
    }
  end

  def batting_indicators
    rows = recent_batter_rows
    batted_balls = rows.select { |row| row.launch_speed.present? }
    exit_velocities = numeric_values(batted_balls, :launch_speed)
    launch_angles = numeric_values(batted_balls, :launch_angle)

    {
      pitches_seen: rows.length,
      game_count: rows.map(&:game_pk).compact.uniq.length,
      latest_game_date: rows.filter_map(&:game_date).max,
      batted_ball_count: batted_balls.length,
      average_exit_velocity: average(exit_velocities),
      max_exit_velocity: rounded(exit_velocities.max),
      average_launch_angle: average(launch_angles),
      hard_hit_percentage: percentage(exit_velocities.count { |value| value >= 95.0 }, exit_velocities.length)
    }
  end

  def recent_pitcher_rows
    @recent_pitcher_rows ||= recent_pitch_scope.where(pitcher: player.mlb_id).to_a
  end

  def recent_batter_rows
    @recent_batter_rows ||= recent_pitch_scope.where(batter: player.mlb_id).to_a
  end

  def recent_pitch_scope
    PitchDatum.order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc).limit(PITCH_SAMPLE_SIZE)
  end

  def numeric_values(rows, attribute)
    rows.filter_map { |row| row.public_send(attribute)&.to_f }
  end

  def average(values)
    return nil if values.empty?

    rounded(values.sum / values.length)
  end

  def percentage(numerator, denominator)
    return nil if denominator.zero?

    rounded((numerator.to_f / denominator) * 100)
  end

  def rounded(value)
    value&.round(1)
  end

  def source_metadata
    datasets = source_datasets.compact

    {
      last_updated_at: datasets.filter_map { |dataset| dataset[:last_updated_at] }.max,
      sources: datasets.filter_map { |dataset| dataset[:source_name] }.uniq,
      datasets: datasets
    }
  end

  def source_datasets
    [
      dataset("player", "DiamondIQ", player.updated_at),
      dataset("profile", player.profile&.source_name, player.profile&.last_synced_at),
      dataset_for_records("positions", player.player_positions.to_a, :source_name, :last_synced_at),
      dataset_for_records("memberships", memberships, :source_name, :last_synced_at),
      dataset_for_records("season_stats", all_season_rows, nil, :updated_at, source_name: "Imported season stats"),
      benchmark_dataset,
      pitch_dataset
    ]
  end

  def dataset(name, source_name, last_updated_at)
    return nil if last_updated_at.nil?

    { name: name, source_name: source_name, last_updated_at: last_updated_at }
  end

  def dataset_for_records(name, records, source_attribute, timestamp_attribute, source_name: nil)
    return nil if records.empty?

    sources = source_name || records.filter_map { |record| record.public_send(source_attribute) }.uniq.join(", ")
    dataset(name, sources.presence, records.filter_map { |record| record.public_send(timestamp_attribute) }.max)
  end

  def pitch_dataset
    rows = (recent_pitcher_rows + recent_batter_rows).uniq(&:id)
    return nil if rows.empty?

    timestamp = rows.filter_map { |row| row.fetched_at_utc || row.updated_at }.max
    dataset("pitch_data", "Baseball Savant", timestamp)
  end

  def benchmark_dataset
    record = player.player_metric_percentiles
      .for_version(DailyAnalyticsRefresh::CALCULATION_VERSION)
      .order(calculated_at: :desc)
      .first
    dataset("contextual_benchmarks", record&.source_name, record&.calculated_at)
  end
end
