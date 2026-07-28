class NeedProfileDiscoveryQuery
  DEFAULT_LIMIT = 20
  MAX_LIMIT = 50

  def initialize(need_profile:, filters: {}, excluded_player_ids: [])
    @need_profile = need_profile
    @filters = filters.to_h.with_indifferent_access
    @excluded_player_ids = Array(excluded_player_ids)
  end

  def result
    players = filtered_players
    stats_by_player = stats_by_player(players)
    candidates = players.filter_map do |player|
      fit = NeedProfileFitCalculator.new(
        need_profile: need_profile,
        player: player,
        season_stats: stats_by_player.fetch(player.id, []),
        latest_season: latest_season
      ).result
      next if fit.fetch(:score) < minimum_fit

      serialize(player, fit)
    end
    candidates.sort_by { |candidate| [ -candidate.fetch(:calculated_fit_score), candidate.dig(:player, :full_name) ] }
      .first(limit)
  end

  private

  attr_reader :need_profile, :filters, :excluded_player_ids

  def performance_stat_keys
    Array(need_profile.criteria["performance"]).filter_map { |target| target.to_h["stat_key"].to_s.presence }.map(&:downcase).uniq
  end

  def latest_season
    @latest_season ||= PlayerSeasonStat.maximum(:season)
  end

  def stats_by_player(players)
    return Hash.new { |hash, key| hash[key] = [] } if players.empty? || performance_stat_keys.empty? || latest_season.nil?

    PlayerSeasonStat.joins(:stat_type)
      .where(player_id: players.map(&:id), season: latest_season)
      .where("lower(stat_types.name) IN (?)", performance_stat_keys)
      .where.not(scope_type: "league")
      .includes(:stat_type)
      .to_a
      .group_by(&:player_id)
  end

  def filtered_players
    scope = Player.includes(:team, :profile, player_positions: :position)
      .where.not(id: excluded_player_ids)
    scope = scope.where.not(team_id: need_profile.team_id) unless filters[:include_organization].to_s == "true"

    desired_positions = Array(filters[:position_types].presence || filters[:position_type].presence ||
      need_profile.criteria["position_types"]).compact
    if desired_positions.any?
      scope = scope.joins(player_positions: :position)
        .where(positions: { position_type: desired_positions })
        .distinct
    end

    scope = scope.joins(:profile).where(player_profiles: { bats: Array(filters[:bats]) }) if filters[:bats].present?
    scope = scope.joins(:profile).where(player_profiles: { throws: Array(filters[:throws]) }) if filters[:throws].present?
    scope = scope.where(team_id: filters[:team_id]) if filters[:team_id].present?
    if filters[:name].present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(filters[:name].to_s.strip)}%"
      scope = scope.where("concat_ws(' ', players.first_name, players.last_name) ILIKE ?", pattern)
    end

    scope.to_a.select { |player| age_matches?(player) }
  end

  def age_matches?(player)
    age = player.profile&.age
    minimum = Integer(filters[:age_min], exception: false)
    maximum = Integer(filters[:age_max], exception: false)
    return true unless minimum || maximum
    return false unless age

    (!minimum || age >= minimum) && (!maximum || age <= maximum)
  end

  def minimum_fit
    Float(filters[:min_fit], exception: false)&.clamp(0, 100) || 0
  end

  def limit
    (Integer(filters[:limit], exception: false) || DEFAULT_LIMIT).clamp(1, MAX_LIMIT)
  end

  def serialize(player, fit)
    position = player.player_positions.find(&:is_primary?)&.position || player.player_positions.first&.position
    {
      calculated_fit_score: fit.fetch(:score),
      fit_breakdown: fit.fetch(:breakdown),
      player: {
        id: player.id,
        mlb_id: player.mlb_id,
        full_name: player.full_name,
        headshot_url: player.profile&.headshot_url,
        age: player.profile&.age,
        bats: player.profile&.bats,
        throws: player.profile&.throws,
        position: position && {
          abbreviation: position.abbreviation,
          name: position.name,
          position_type: position.position_type
        },
        team: player.team && {
          id: player.team.id,
          name: player.team.name,
          abbreviation: player.team.abbreviation
        }
      }
    }
  end
end
