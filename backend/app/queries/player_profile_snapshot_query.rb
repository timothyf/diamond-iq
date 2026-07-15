class PlayerProfileSnapshotQuery
  PITCH_SAMPLE_SIZE = 100
  SEASON_CATEGORIES = %w[batting pitching].freeze

  def initialize(player:, on: Date.current)
    @player = player
    @on = on
  end

  def result
    {
      season_overview: season_overview,
      current_membership: serialize_membership(current_membership),
      team_history: memberships.map { |membership| serialize_membership(membership) },
      recent_pitch_indicators: recent_pitch_indicators,
      source_metadata: source_metadata
    }
  end

  private

  attr_reader :player, :on

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

  def latest_season
    @latest_season ||= player.player_season_stats.maximum(:season)
  end

  def season_rows
    @season_rows ||= player.player_season_stats
      .where(season: latest_season)
      .includes(:stat_type, :team)
      .to_a
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
    season_rows
      .select { |row| row.stat_type.category == category && aliases.include?(row.stat_type.name) }
      .min_by do |row|
        [ aliases.index(row.stat_type.name), scope_priority(row), -row.updated_at.to_f ]
      end
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
      dataset_for_records("season_stats", season_rows, nil, :updated_at, source_name: "Imported season stats"),
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
end
