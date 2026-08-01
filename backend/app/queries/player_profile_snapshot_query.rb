class PlayerProfileSnapshotQuery
  PITCH_SAMPLE_SIZE = 100
  SEASON_CATEGORIES = %w[batting pitching].freeze
  BATTING_RATE_KEYS = %w[avg obp slg ops].freeze
  PITCHING_RATE_KEYS = %w[ERA whip avg].freeze
  ADVANCED_BATTING_GROUPS = [
    {
      key: "rate_statistics",
      label: "Rate statistics",
      columns: [
        { key: "bb_percentage", label: "BB%", unit: "percent" },
        { key: "k_percentage", label: "K%", unit: "percent" },
        { key: "bb_per_k", label: "BB/K", unit: "ratio" },
        { key: "iso", label: "ISO", unit: "rate" },
        { key: "babip", label: "BABIP", unit: "rate" }
      ]
    },
    {
      key: "run_creation",
      label: "Run creation",
      columns: [
        { key: "woba", label: "wOBA", unit: "rate" },
        { key: "wrc_plus", label: "wRC+", unit: "index" },
        { key: "ops_plus", label: "OPS+", unit: "index" }
      ]
    },
    {
      key: "value",
      label: "Value",
      columns: [
        { key: "offensive_runs", label: "Offensive Runs", unit: "runs" },
        { key: "baserunning_runs", label: "Baserunning Runs", unit: "runs" },
        { key: "defensive_value", label: "Defensive Value", unit: "runs" },
        { key: "war", label: "WAR", unit: "war" }
      ]
    },
    {
      key: "batted_ball_profile",
      label: "Batted-ball profile",
      columns: [
        { key: "ground_ball_percentage", label: "GB%", unit: "percent" },
        { key: "fly_ball_percentage", label: "FB%", unit: "percent" },
        { key: "line_drive_percentage", label: "LD%", unit: "percent" },
        { key: "pull_percentage", label: "Pull%", unit: "percent" },
        { key: "center_percentage", label: "Center%", unit: "percent" },
        { key: "opposite_field_percentage", label: "Opposite-field%", unit: "percent" }
      ]
    },
    {
      key: "plate_discipline",
      label: "Plate discipline",
      columns: [
        { key: "swing_percentage", label: "Swing%", unit: "percent" },
        { key: "chase_percentage", label: "Chase%", unit: "percent" },
        { key: "contact_percentage", label: "Contact%", unit: "percent" },
        { key: "zone_contact_percentage", label: "Zone Contact%", unit: "percent" },
        { key: "swinging_strike_percentage", label: "SwStr%", unit: "percent" }
      ]
    }
  ].freeze
  ADVANCED_PITCHING_GROUPS = [
    {
      key: "rate_and_outcome_statistics",
      label: "Rate and outcome statistics",
      columns: [
        { key: "k_percentage", label: "K%", unit: "percent" },
        { key: "bb_percentage", label: "BB%", unit: "percent" },
        { key: "k_minus_bb_percentage", label: "K-BB%", unit: "percent" },
        { key: "k_per_bb", label: "K/BB", unit: "ratio" },
        { key: "hbp_percentage", label: "HBP%", unit: "percent" },
        { key: "hr_percentage", label: "HR%", unit: "percent" },
        { key: "babip", label: "BABIP", unit: "rate" },
        { key: "lob_percentage", label: "LOB%", unit: "percent" },
        { key: "era", label: "ERA", unit: "pitching_rate" },
        { key: "fip", label: "FIP", unit: "pitching_rate" },
        { key: "xfip", label: "xFIP", unit: "pitching_rate" }
      ]
    },
    {
      key: "run_prevention_and_expected_performance",
      label: "Run prevention and expected performance",
      columns: [
        { key: "era", label: "ERA", unit: "pitching_rate" },
        { key: "era_minus", label: "ERA-", unit: "index" },
        { key: "era_plus", label: "ERA+", unit: "index" },
        { key: "fip", label: "FIP", unit: "pitching_rate" },
        { key: "fip_minus", label: "FIP-", unit: "index" },
        { key: "xfip", label: "xFIP", unit: "pitching_rate" },
        { key: "xfip_minus", label: "xFIP-", unit: "index" },
        { key: "siera", label: "SIERA", unit: "pitching_rate" },
        { key: "xera", label: "xERA", unit: "pitching_rate" },
        { key: "ra9", label: "RA9", unit: "pitching_rate" },
        { key: "runs_allowed_per_nine", label: "Runs allowed per 9", unit: "pitching_rate" },
        { key: "earned_runs_allowed_per_nine", label: "Earned runs allowed per 9", unit: "pitching_rate" },
        { key: "expected_woba_allowed", label: "Expected wOBA allowed", unit: "rate" },
        { key: "woba_allowed", label: "wOBA allowed", unit: "rate" }
      ]
    },
    {
      key: "pitcher_value",
      label: "Pitcher value",
      description: "A high-level summary of how much value the pitcher produced.",
      columns: [
        { key: "war", label: "WAR", unit: "war" },
        { key: "ra9_war", label: "RA9-WAR", unit: "war" },
        { key: "wpa", label: "WPA", unit: "war" },
        { key: "wpa_per_li", label: "WPA/LI", unit: "war" },
        { key: "re24", label: "RE24", unit: "runs" },
        { key: "clutch", label: "Clutch", unit: "ratio" },
        { key: "runs_above_replacement", label: "Runs above replacement", unit: "runs" },
        { key: "runs_above_average", label: "Runs above average", unit: "runs" },
        { key: "pitching_runs", label: "Pitching runs", unit: "runs" },
        { key: "leverage_index", label: "Leverage index", unit: "ratio" },
        { key: "shutdowns", label: "Shutdowns", unit: "count" },
        { key: "meltdowns", label: "Meltdowns", unit: "count" }
      ]
    }
  ].freeze
  TRANSACTION_HISTORY_SOURCE_NAME = "MLB Stats API transactions"

  def initialize(player:, on: Date.current, analysis_range: nil)
    @player = player
    @on = on
    @analysis_range = analysis_range || PlayerAnalysisRange.resolve(player: player)
  end

  def result
    {
      season_overview: season_overview,
      career_overview: career_overview,
      advanced_stats: advanced_stats,
      similar_players: SimilarPlayersQuery.new(
        player: player,
        season: latest_season,
        category: preferred_category
      ).result,
      display_team: serialize_team(display_team),
      external_ids: external_ids,
      current_membership: serialize_membership(current_membership),
      team_history: organization_tenures,
      recent_pitch_indicators: recent_pitch_indicators,
      contextual_benchmarks: PlayerBenchmarkSnapshotQuery.new(
        player: player,
        start_date: analysis_range.start_date,
        end_date: analysis_range.end_date
      ).result,
      trend_events: PlayerTrendEventQuery.new(
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

  def display_team
    return current_membership&.team || player.team unless retired_player?

    longest_served_team || player.team
  end

  def retired_player?
    player.profile&.raw_data.to_h["active"] == false
  end

  def external_ids
    mapping = player.player_id_mapping

    {
      baseball_reference: mapping&.baseball_reference_id,
      fangraphs: mapping&.fangraphs_id
    }
  end

  def longest_served_team
    seasons_by_team = player.player_season_stats
      .where.not(team_id: nil)
      .pluck(:team_id, :season)
      .group_by(&:first)
      .transform_values { |rows| rows.map(&:last).uniq }
    team_id, = seasons_by_team.max_by do |candidate_team_id, seasons|
      [ seasons.length, seasons.max || 0, candidate_team_id ]
    end

    Team.find_by(id: team_id) if team_id
  end

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

  def advanced_stats
    category = career_category
    groups = advanced_groups(category)
    return empty_advanced_stats if groups.empty?

    seasons = career_rows_by_season(category).sort.map do |season, rows|
      {
        season: season,
        teams: rows.filter_map(&:team).uniq(&:id).map { |team| serialize_team(team) },
        values: advanced_values(category, rows)
      }
    end

    {
      category: category,
      groups: groups,
      seasons: seasons,
      career: { values: advanced_values(category, career_rows(category), career: true) }
    }
  end

  def empty_advanced_stats
    { category: preferred_category, groups: advanced_groups(preferred_category), seasons: [], career: { values: {} } }
  end

  def advanced_groups(category)
    return ADVANCED_BATTING_GROUPS if category == "batting"
    return ADVANCED_PITCHING_GROUPS if category == "pitching"

    []
  end

  def advanced_values(category, rows, career: false)
    return advanced_batting_values(rows, career: career) if category == "batting"

    advanced_pitching_values(rows, career: career)
  end

  def advanced_batting_values(rows, career: false)
    plate_appearances = advanced_count(rows, %w[plateAppearances PA], career: career) ||
      derived_plate_appearances(rows, career: career)
    walks = advanced_count(rows, %w[baseOnBalls BB], career: career)
    strikeouts = advanced_count(rows, %w[strikeOuts SO], career: career)
    hits = advanced_count(rows, %w[hits H], career: career)
    home_runs = advanced_count(rows, %w[homeRuns HR], career: career)
    at_bats = advanced_count(rows, %w[atBats AB], career: career)
    sacrifice_flies = advanced_count(rows, %w[sacFlies SF], career: career)
    average = advanced_rate(rows, %w[avg AVG], %w[atBats AB], career: career)
    slugging = advanced_rate(rows, %w[slg SLG], %w[atBats AB], career: career)

    {
      bb_percentage: numeric_advanced_value(
        divide(walks, plate_appearances) || normalized_percentage_rate(advanced_rate(rows, [ "BB%", "walksPerPlateAppearance" ], %w[plateAppearances PA], career: career))
      ),
      k_percentage: numeric_advanced_value(
        divide(strikeouts, plate_appearances) || normalized_percentage_rate(advanced_rate(rows, [ "K%", "strikeoutsPerPlateAppearance" ], %w[plateAppearances PA], career: career))
      ),
      bb_per_k: numeric_advanced_value(
        divide(walks, strikeouts) || advanced_rate(rows, [ "BB/K", "walksPerStrikeout" ], %w[plateAppearances PA], career: career)
      ),
      iso: numeric_advanced_value(slugging && average ? slugging - average : advanced_rate(rows, %w[ISO iso], %w[plateAppearances PA], career: career)),
      babip: numeric_advanced_value(
        divide(hits && home_runs ? hits - home_runs : nil, at_bats && strikeouts && home_runs && sacrifice_flies ? at_bats - strikeouts - home_runs + sacrifice_flies : nil) ||
          advanced_rate(rows, %w[BABIP babip BAbip], %w[atBats AB], career: career)
      ),
      woba: numeric_advanced_value(advanced_rate(rows, %w[wOBA woba], %w[plateAppearances PA], career: career)),
      wrc_plus: numeric_advanced_value(advanced_rate(rows, [ "wRC+", "wrc+", "wRCPlus", "wrcPlus" ], %w[plateAppearances PA], career: career)),
      ops_plus: numeric_advanced_value(advanced_rate(rows, [ "OPS+", "ops+", "OPSPlus", "opsPlus" ], %w[plateAppearances PA], career: career)),
      offensive_runs: numeric_advanced_value(advanced_count(rows, %w[Offense offensiveRuns], career: career)),
      baserunning_runs: numeric_advanced_value(advanced_count(rows, %w[BaseRunning baserunningRuns], career: career)),
      defensive_value: numeric_advanced_value(advanced_count(rows, %w[Defense defensiveValue], career: career)),
      war: numeric_advanced_value(advanced_count(rows, %w[WAR war], career: career)),
      ground_ball_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "GB%", "groundBallPercentage" ], career: career)),
      fly_ball_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "FB%", "flyBallPercentage" ], career: career)),
      line_drive_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "LD%", "lineDrivePercentage" ], career: career)),
      pull_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Pull%", "pullPercentage" ], career: career)),
      center_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Cent%", "Center%", "centerPercentage" ], career: career)),
      opposite_field_percentage: numeric_advanced_value(advanced_batted_ball_rate(rows, [ "Oppo%", "oppositeFieldPercentage" ], career: career)),
      swing_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Swing%", "swingPercentage" ], career: career)),
      chase_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "O-Swing%", "Chase%", "chasePercentage" ], career: career)),
      contact_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Contact%", "contactPercentage" ], career: career)),
      zone_contact_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "Z-Contact%", "zoneContactPercentage" ], career: career)),
      swinging_strike_percentage: numeric_advanced_value(advanced_plate_discipline_rate(rows, [ "SwStr%", "swingingStrikePercentage" ], career: career))
    }
  end

  def advanced_pitching_values(rows, career: false)
    batters_faced = advanced_count(rows, %w[battersFaced TBF], career: career)
    strikeouts = advanced_count(rows, %w[strikeOuts SO], career: career)
    walks = advanced_count(rows, %w[baseOnBalls BB], career: career)
    hit_batters = advanced_count(rows, %w[hitByPitch hitBatsmen HBP], career: career)
    home_runs = advanced_count(rows, %w[homeRuns HR], career: career)
    k_percentage = divide(strikeouts, batters_faced) ||
      normalized_percentage_rate(advanced_rate(rows, [ "K%", "strikeoutPercentage" ], %w[battersFaced TBF], career: career))
    bb_percentage = divide(walks, batters_faced) ||
      normalized_percentage_rate(advanced_rate(rows, [ "BB%", "walkPercentage" ], %w[battersFaced TBF], career: career))
    innings = advanced_pitching_innings(rows)
    runs = advanced_count(rows, %w[runs R], career: career)
    earned_runs = advanced_count(rows, %w[earnedRuns ER], career: career)
    era_minus = advanced_rate(rows, [ "ERA-", "eraMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)
    era = career ? pitching_era : season_pitching_era(rows)
    runs_per_nine = divide(runs && innings ? runs * 9 : nil, innings)
    earned_runs_per_nine = divide(earned_runs && innings ? earned_runs * 9 : nil, innings)

    {
      k_percentage: numeric_advanced_value(k_percentage),
      bb_percentage: numeric_advanced_value(bb_percentage),
      k_minus_bb_percentage: numeric_advanced_value(
        k_percentage && bb_percentage ? k_percentage - bb_percentage : advanced_rate(rows, [ "K-BB%" ], %w[battersFaced TBF], career: career)
      ),
      k_per_bb: numeric_advanced_value(
        divide(strikeouts, walks) || advanced_rate(rows, [ "K/BB", "strikeoutWalkRatio" ], %w[battersFaced TBF], career: career)
      ),
      hbp_percentage: numeric_advanced_value(divide(hit_batters, batters_faced)),
      hr_percentage: numeric_advanced_value(divide(home_runs, batters_faced)),
      babip: numeric_advanced_value(advanced_rate(rows, %w[BABIP babip BAbip], %w[battersFaced TBF], career: career)),
      lob_percentage: numeric_advanced_value(
        advanced_rate(rows, [ "LOB%", "leftOnBasePercentage" ], %w[inningsPitched IP], career: career, innings_weight: true)
      ),
      era: numeric_advanced_value(era),
      era_minus: numeric_advanced_value(era_minus),
      era_plus: numeric_advanced_value(
        advanced_rate(rows, [ "ERA+", "eraPlus" ], %w[inningsPitched IP], career: career, innings_weight: true) ||
          divide(10_000, era_minus)
      ),
      fip: numeric_advanced_value(advanced_rate(rows, %w[FIP fip], %w[inningsPitched IP], career: career, innings_weight: true)),
      fip_minus: numeric_advanced_value(advanced_rate(rows, [ "FIP-", "fipMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)),
      xfip: numeric_advanced_value(advanced_rate(rows, %w[xFIP xfip], %w[inningsPitched IP], career: career, innings_weight: true)),
      xfip_minus: numeric_advanced_value(advanced_rate(rows, [ "xFIP-", "xfipMinus" ], %w[inningsPitched IP], career: career, innings_weight: true)),
      siera: numeric_advanced_value(advanced_rate(rows, %w[SIERA siera], %w[inningsPitched IP], career: career, innings_weight: true)),
      xera: numeric_advanced_value(advanced_rate(rows, %w[xERA xera], %w[inningsPitched IP], career: career, innings_weight: true)),
      ra9: numeric_advanced_value(runs_per_nine),
      runs_allowed_per_nine: numeric_advanced_value(runs_per_nine),
      earned_runs_allowed_per_nine: numeric_advanced_value(earned_runs_per_nine || era),
      expected_woba_allowed: numeric_advanced_value(advanced_rate(rows, %w[xwOBAAllowed xwOBA], %w[battersFaced TBF], career: career)),
      woba_allowed: numeric_advanced_value(advanced_rate(rows, %w[wOBAAllowed wOBA], %w[battersFaced TBF], career: career)),
      war: numeric_advanced_value(advanced_count(rows, %w[WAR war], career: career)),
      ra9_war: numeric_advanced_value(advanced_count(rows, [ "RA9-Wins", "RA9-WAR", "ra9War" ], career: career)),
      wpa: numeric_advanced_value(advanced_count(rows, %w[WPA wpa], career: career)),
      wpa_per_li: numeric_advanced_value(advanced_count(rows, [ "WPA/LI", "wpaPerLi" ], career: career)),
      re24: numeric_advanced_value(advanced_count(rows, %w[RE24 re24], career: career)),
      clutch: numeric_advanced_value(advanced_count(rows, %w[Clutch clutch], career: career)),
      runs_above_replacement: numeric_advanced_value(advanced_count(rows, %w[RAR rar], career: career)),
      runs_above_average: numeric_advanced_value(advanced_count(rows, %w[RAA raa], career: career)),
      pitching_runs: numeric_advanced_value(advanced_count(rows, [ "PitchingRuns", "pitchingRuns" ], career: career)),
      leverage_index: numeric_advanced_value(advanced_rate(rows, %w[pLI leverageIndex], %w[battersFaced TBF], career: career)),
      shutdowns: numeric_advanced_value(advanced_count(rows, %w[SD shutdowns], career: career)),
      meltdowns: numeric_advanced_value(advanced_count(rows, %w[MD meltdowns], career: career))
    }
  end

  def advanced_pitching_innings(rows)
    outs = rows.group_by(&:season).values.filter_map do |season_rows|
      innings = season_additive_value(season_rows, %w[inningsPitched IP])
      innings_to_outs(innings) if innings
    end.sum
    return if outs.zero?

    innings_as_decimal(outs)
  end

  def advanced_batted_ball_rate(rows, aliases, career:)
    value = advanced_rate(rows, aliases, %w[ballsInPlay BIP], career: career)
    value || advanced_rate(rows, aliases, %w[plateAppearances PA], career: career)
  end

  def advanced_plate_discipline_rate(rows, aliases, career:)
    value = advanced_rate(rows, aliases, %w[numberOfPitches Pitches], career: career)
    value || advanced_rate(rows, aliases, %w[plateAppearances PA], career: career)
  end

  def derived_plate_appearances(rows, career:)
    components = [
      advanced_count(rows, %w[atBats AB], career: career),
      advanced_count(rows, %w[baseOnBalls BB], career: career),
      advanced_count(rows, %w[hitByPitch HBP], career: career),
      advanced_count(rows, %w[sacFlies SF], career: career),
      advanced_count(rows, %w[sacBunts SH], career: career)
    ]
    return if components.first.nil?

    components.compact.sum(0.to_d)
  end

  def advanced_count(rows, aliases, career:)
    return season_additive_value(rows, aliases) unless career

    rows.group_by(&:season).values.filter_map { |season_rows| season_additive_value(season_rows, aliases) }.presence&.sum(0.to_d)
  end

  def advanced_rate(rows, aliases, weight_aliases, career:, innings_weight: false)
    return best_stat_row_from(rows, aliases)&.value unless career

    weighted_values = rows.group_by(&:season).values.filter_map do |season_rows|
      value = best_stat_row_from(season_rows, aliases)&.value
      weight = season_additive_value(season_rows, weight_aliases)
      weight ||= derived_plate_appearances(season_rows, career: false) if (weight_aliases & %w[plateAppearances PA]).any?
      next if value.nil? || weight.nil? || !weight.positive?

      normalized_weight = innings_weight ? innings_as_decimal(innings_to_outs(weight)) : weight
      [ value, normalized_weight ]
    end
    return if weighted_values.empty?

    divide(
      weighted_values.sum(0.to_d) { |value, weight| value * weight },
      weighted_values.sum(0.to_d) { |_value, weight| weight }
    )
  end

  def numeric_advanced_value(value)
    value.nil? ? nil : value.to_f
  end

  def normalized_percentage_rate(value)
    return if value.nil?

    value > 1 ? value / 100 : value
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
    return season_batting_obp(rows) if category == "batting" && key == "obp"
    return season_batting_slugging(rows) if category == "batting" && key == "slg"
    return season_batting_ops(rows) if category == "batting" && key == "ops"
    return season_pitching_era(rows) if category == "pitching" && key == "ERA"
    return season_pitching_whip(rows) if category == "pitching" && key == "whip"
    return season_pitching_average(rows) if category == "pitching" && key == "avg"

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

  def season_batting_obp(rows)
    hits = season_additive_value(rows, %w[hits H])
    walks = season_additive_value(rows, %w[baseOnBalls BB])
    hit_by_pitch = season_additive_value(rows, %w[hitByPitch HBP])
    sacrifice_flies = season_additive_value(rows, %w[sacFlies SF])
    at_bats = season_additive_value(rows, %w[atBats AB])
    components = [ hits, walks, hit_by_pitch, sacrifice_flies, at_bats ]
    return season_weighted_rate(rows, %w[obp OBP], %w[atBats AB]) if components.any?(&:nil?)

    divide(hits + walks + hit_by_pitch, at_bats + walks + hit_by_pitch + sacrifice_flies)
  end

  def season_batting_ops(rows)
    obp = season_batting_obp(rows)
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

  def season_pitching_average(rows)
    hits = season_additive_value(rows, %w[hits H])
    at_bats = season_additive_value(rows, %w[atBats AB])
    return season_weighted_rate(rows, %w[avg AVG], %w[inningsPitched IP], innings_weight: true) if hits.nil? || at_bats.nil?

    divide(hits, at_bats)
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
    return batting_obp if category == "batting" && key == "obp"
    return batting_slugging if category == "batting" && key == "slg"
    return batting_ops if category == "batting" && key == "ops"
    return pitching_era if category == "pitching" && key == "ERA"
    return pitching_whip if category == "pitching" && key == "whip"
    return pitching_average if category == "pitching" && key == "avg"

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

  def batting_obp
    hits = additive_career_value("batting", %w[hits H])
    walks = additive_career_value("batting", %w[baseOnBalls BB])
    hit_by_pitch = additive_career_value("batting", %w[hitByPitch HBP])
    sacrifice_flies = additive_career_value("batting", %w[sacFlies SF])
    at_bats = additive_career_value("batting", %w[atBats AB])
    components = [ hits, walks, hit_by_pitch, sacrifice_flies, at_bats ]
    return weighted_career_rate("batting", %w[obp OBP], %w[atBats AB]) if components.any?(&:nil?)

    divide(hits + walks + hit_by_pitch, at_bats + walks + hit_by_pitch + sacrifice_flies)
  end

  def batting_ops
    obp = batting_obp
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

  def pitching_average
    hits = additive_career_value("pitching", %w[hits H])
    at_bats = additive_career_value("pitching", %w[atBats AB])
    return weighted_career_rate("pitching", %w[avg AVG], %w[inningsPitched IP], innings_weight: true) if hits.nil? || at_bats.nil?

    divide(hits, at_bats)
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

  def organization_tenures
    groups = memberships.sort_by { |membership| [ membership.starts_on, membership.id ] }.each_with_object([]) do |membership, output|
      previous = output.last
      if mergeable_organization_window?(previous, membership)
        if transaction_history_membership?(membership)
          previous[:starts_on] = membership.starts_on
          previous[:ends_on] = membership.ends_on
          previous[:transaction_history] = true
        elsif !previous[:transaction_history]
          previous[:starts_on] = [ previous[:starts_on], membership.starts_on ].min
          previous[:ends_on] = merged_membership_end(previous[:ends_on], membership.ends_on)
        end
        previous[:latest_membership] = membership
        previous[:current] ||= membership == current_membership
      else
        output << {
          starts_on: membership.starts_on,
          ends_on: membership.ends_on,
          latest_membership: membership,
          current: membership == current_membership,
          transaction_history: transaction_history_membership?(membership)
        }
      end
    end

    groups.reverse.map do |group|
      serialized = serialize_membership(group[:latest_membership]).merge(
        starts_on: group[:starts_on],
        ends_on: group[:ends_on],
        current: group[:current]
      )
      next serialized if group[:current]

      serialized.merge(
        roster_status: "organization",
        injured: false,
        source_status_description: "Organization tenure"
      )
    end
  end

  def mergeable_organization_window?(group, membership)
    return false if group.nil? || group[:latest_membership].team_id != membership.team_id
    return true if group[:ends_on].nil?

    membership.starts_on <= group[:ends_on] + 1.day
  end

  def merged_membership_end(first, second)
    return nil if first.nil? || second.nil?

    [ first, second ].max
  end

  def transaction_history_membership?(membership)
    membership.source_name == TRANSACTION_HISTORY_SOURCE_NAME
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
