class NeedProfileFitCalculator
  RATE_STAT_KEYS = %w[avg obp slg ops era whip].freeze

  def initialize(need_profile:, player:, on: Date.current, season_stats: nil, latest_season: nil)
    @need_profile = need_profile
    @player = player
    @on = on
    @provided_season_stats = season_stats
    @provided_latest_season = latest_season
  end

  def result
    components = {
      "position" => position_component,
      "handedness" => handedness_component,
      "age" => age_component,
      "performance" => performance_component
    }
    weights = need_profile.normalized_weights.transform_values(&:to_f)
    weight_total = weights.values.sum
    score = components.sum { |key, value| value.fetch("score") * weights.fetch(key) } / weight_total

    {
      score: score.round(2),
      breakdown: {
        "components" => components,
        "weights" => weights,
        "season" => latest_season,
        "calculation_version" => "1.0.0"
      }
    }
  end

  private

  attr_reader :need_profile, :player, :on

  def criteria
    @criteria ||= need_profile.criteria.to_h
  end

  def position_component
    desired = Array(criteria["position_types"])
    actual = player.player_positions.map { |assignment| assignment.position.position_type }.uniq
    matched = desired.empty? || (desired & actual).any?
    component(matched ? 100 : 0, desired: desired, actual: actual, matched: matched)
  end

  def handedness_component
    requirements = []
    bats = Array(criteria["bats"])
    throws = Array(criteria["throws"])
    requirements << [ "bats", bats, player.profile&.bats ] if bats.any?
    requirements << [ "throws", throws, player.profile&.throws ] if throws.any?
    return component(100, requirements: []) if requirements.empty?

    matches = requirements.count { |_key, desired, actual| desired.include?(actual) }
    component(
      matches.to_f / requirements.length * 100,
      requirements: requirements.to_h { |key, desired, actual| [ key, { "desired" => desired, "actual" => actual } ] }
    )
  end

  def age_component
    range = criteria["age"].to_h
    age = player.profile&.age(on: on)
    return component(100, desired: range, actual: age) if range.blank?
    return component(0, desired: range, actual: nil) if age.nil?

    minimum = Integer(range["min"], exception: false)
    maximum = Integer(range["max"], exception: false)
    distance = if minimum && age < minimum
      minimum - age
    elsif maximum && age > maximum
      age - maximum
    else
      0
    end
    component([ 100 - (distance * 15), 0 ].max, desired: range, actual: age)
  end

  def performance_component
    targets = Array(criteria["performance"])
    return component(100, targets: []) if targets.empty?

    scored_targets = targets.map do |raw_target|
      target = raw_target.to_h.stringify_keys
      actual = stat_value(target.fetch("stat_key"))
      target_value = target.fetch("target").to_f
      score = if actual.nil?
        0
      elsif target.fetch("direction") == "lower"
        actual <= target_value ? 100 : (target_value / actual * 100)
      else
        actual >= target_value ? 100 : (actual / target_value * 100)
      end
      {
        "stat_key" => target.fetch("stat_key"),
        "direction" => target.fetch("direction"),
        "target" => target_value,
        "actual" => actual,
        "score" => score.clamp(0, 100).round(2),
        "weight" => target["weight"].to_f.positive? ? target["weight"].to_f : 1
      }
    end
    total_weight = scored_targets.sum { |target| target.fetch("weight") }
    score = scored_targets.sum { |target| target.fetch("score") * target.fetch("weight") } / total_weight
    component(score, targets: scored_targets)
  end

  def stat_value(stat_key)
    matching = season_stats.select do |row|
      row.stat_type.name.casecmp?(stat_key.to_s) && row.stat_type.category == performance_category
    end
    combined = matching.find { |row| row.scope_type == "combined" }
    return combined.value.to_f if combined

    team_rows = matching.select { |row| row.scope_type == "team" }
    return if team_rows.empty?
    return team_rows.first.value.to_f if RATE_STAT_KEYS.include?(stat_key.to_s.downcase)

    team_rows.sum { |row| row.value.to_f }
  end

  def latest_season
    @latest_season ||= @provided_latest_season || if player.player_season_stats.loaded?
      player.player_season_stats.map(&:season).compact.max
    else
      PlayerSeasonStat.where(player: player).maximum(:season)
    end
  end

  def season_stats
    @season_stats ||= if @provided_season_stats
      @provided_season_stats
    elsif latest_season
      if player.player_season_stats.loaded?
        player.player_season_stats.select do |row|
          row.season == latest_season && row.scope_type != "league"
        end
      else
        PlayerSeasonStat.where(player: player, season: latest_season)
          .where.not(scope_type: "league")
          .includes(:stat_type)
          .to_a
      end
    else
      []
    end
  end

  def performance_category
    @performance_category ||= begin
      position_types = player.player_positions.map { |assignment| assignment.position.position_type }
      position_types.include?("pitcher") && !position_types.include?("outfielder") ? "pitching" : "batting"
    end
  end

  def component(score, details = {})
    details.stringify_keys.merge("score" => score.to_f.round(2))
  end
end
