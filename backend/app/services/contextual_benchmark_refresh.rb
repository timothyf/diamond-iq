class ContextualBenchmarkRefresh
  SOURCE_NAME = "DiamondIQ contextual benchmarks"
  METRICS = {
    "ops" => { group: "batting", label: "OPS", direction: "higher_better", unit: "rate" },
    "average_exit_velocity" => { group: "batting", label: "Average exit velocity", direction: "higher_better", unit: "mph" },
    "hard_hit_percentage" => { group: "batting", label: "Hard-hit rate", direction: "higher_better", unit: "percent" },
    "batter_whiff_percentage" => { group: "batting", label: "Whiff rate", direction: "lower_better", unit: "percent" },
    "batter_chase_percentage" => { group: "batting", label: "Chase rate", direction: "lower_better", unit: "percent" },
    "pitcher_average_velocity" => { group: "pitching", label: "Average velocity", direction: "higher_better", unit: "mph" },
    "pitcher_average_spin_rate" => { group: "pitching", label: "Average spin rate", direction: "neutral", unit: "rpm" },
    "pitcher_whiff_percentage" => { group: "pitching", label: "Whiff rate", direction: "higher_better", unit: "percent" },
    "pitcher_chase_percentage" => { group: "pitching", label: "Chase rate", direction: "higher_better", unit: "percent" },
    "pitch_usage_percentage" => { group: "pitch_type", label: "Pitch usage", direction: "neutral", unit: "percent" }
  }.freeze

  def self.call(start_date:, end_date:, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    new(start_date: start_date, end_date: end_date, calculation_version: calculation_version).call
  end

  def initialize(start_date:, end_date:, calculation_version:)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @calculation_version = calculation_version.to_s.strip
    @calculated_at = Time.current
  end

  def call
    return failure("End date must be on or after start date") if end_date < start_date
    return failure("Calculation version is required") if calculation_version.blank?

    current = observations(start_date, end_date)
    previous = observations(previous_start_date, previous_end_date).index_by { |row| observation_identity(row) }
    benchmark_count = 0
    percentile_count = 0

    ApplicationRecord.transaction do
      remove_existing!
      grouped_observations(current).each do |identity, metric_rows|
        peer_groups(metric_rows).each do |peer_group_type, peer_group_key, peers|
          benchmark = create_benchmark!(identity, peer_group_type, peer_group_key, peers)
          benchmark_count += 1
          percentile_count += create_percentiles!(benchmark, peers, previous)
        end
      end
    end

    {
      success: true,
      message: "Refreshed contextual benchmarks for #{start_date.iso8601} through #{end_date.iso8601}",
      data: {
        source_start_date: start_date.iso8601,
        source_end_date: end_date.iso8601,
        previous_start_date: previous_start_date.iso8601,
        previous_end_date: previous_end_date.iso8601,
        calculation_version: calculation_version,
        benchmark_count: benchmark_count,
        percentile_count: percentile_count,
        player_count: current.map { |row| row[:player_id] }.uniq.length
      }
    }
  rescue ArgumentError => error
    failure(error.message)
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to refresh contextual benchmarks: #{error.message}")
  end

  private

  attr_reader :start_date, :end_date, :calculation_version, :calculated_at

  def observations(range_start, range_end)
    batting_observations(range_start, range_end) +
      batter_statcast_observations(range_start, range_end) +
      pitcher_statcast_observations(range_start, range_end) +
      pitch_usage_observations(range_start, range_end)
  end

  def batting_observations(range_start, range_end)
    daily_rows(PlayerBattingDaily, range_start, range_end).group_by(&:player_id).filter_map do |player_id, rows|
      totals = sum_metrics(rows, %w[plate_appearances at_bats hits doubles triples home_runs walks])
      next if totals["plate_appearances"].zero? || totals["at_bats"].zero?

      value = ops(totals)
      observation(
        player_id: player_id,
        metric_key: "ops",
        value: value,
        sample_size: totals["plate_appearances"],
        numerator: value * totals["plate_appearances"],
        denominator: totals["plate_appearances"],
        components: totals
      )
    end
  end

  def batter_statcast_observations(range_start, range_end)
    rows = daily_rows(BatterSplitSummary, range_start, range_end).select { |row| row.split_type == "home_away" }
    rows.group_by(&:player_id).flat_map do |player_id, player_rows|
      batted_balls = sum_metric(player_rows, "exit_velocity_sample_size", fallback: "batted_balls")
      swings = sum_metric(player_rows, "swings")
      chase_opportunities = sum_metric(player_rows, "chase_opportunities")
      exit_velocity_sum = weighted_metric_sum(player_rows, "average_exit_velocity", "exit_velocity_sample_size", fallback: "batted_balls")
      hard_hit_sum = weighted_percentage_sum(player_rows, "hard_hit_percentage", "batted_balls")
      whiffs = sum_metric(player_rows, "whiffs")
      chases = sum_metric(player_rows, "chases")

      [
        rate_observation(player_id, "average_exit_velocity", exit_velocity_sum, batted_balls),
        rate_observation(player_id, "hard_hit_percentage", hard_hit_sum, batted_balls, scale: 100),
        rate_observation(player_id, "batter_whiff_percentage", whiffs, swings, scale: 100),
        rate_observation(player_id, "batter_chase_percentage", chases, chase_opportunities, scale: 100)
      ].compact
    end
  end

  def pitcher_statcast_observations(range_start, range_end)
    rows = daily_rows(PitcherSplitSummary, range_start, range_end).select { |row| row.split_type == "home_away" }
    rows.group_by(&:player_id).flat_map do |player_id, player_rows|
      velocity_samples = sum_metric(player_rows, "velocity_sample_size", fallback: "pitch_count")
      spin_samples = sum_metric(player_rows, "spin_sample_size", fallback: "pitch_count")
      swings = sum_metric(player_rows, "swings")
      chase_opportunities = sum_metric(player_rows, "chase_opportunities")

      [
        rate_observation(player_id, "pitcher_average_velocity", weighted_metric_sum(player_rows, "average_velocity", "velocity_sample_size", fallback: "pitch_count"), velocity_samples),
        rate_observation(player_id, "pitcher_average_spin_rate", weighted_metric_sum(player_rows, "average_spin_rate", "spin_sample_size", fallback: "pitch_count"), spin_samples),
        rate_observation(player_id, "pitcher_whiff_percentage", sum_metric(player_rows, "whiffs"), swings, scale: 100),
        rate_observation(player_id, "pitcher_chase_percentage", sum_metric(player_rows, "chases"), chase_opportunities, scale: 100)
      ].compact
    end
  end

  def pitch_usage_observations(range_start, range_end)
    rows = daily_rows(PitcherPitchTypeDaily, range_start, range_end)
    totals_by_player = rows.group_by(&:player_id).transform_values { |player_rows| sum_metric(player_rows, "pitch_count") }

    rows.group_by { |row| [ row.player_id, row.pitch_type ] }.filter_map do |(player_id, pitch_type), pitch_rows|
      total_pitches = totals_by_player.fetch(player_id)
      type_pitches = sum_metric(pitch_rows, "pitch_count")
      next if total_pitches.zero?

      rate_observation(
        player_id,
        "pitch_usage_percentage",
        type_pitches,
        total_pitches,
        scale: 100,
        dimension_type: "pitch_type",
        dimension_value: pitch_type
      )
    end
  end

  def daily_rows(model, range_start, range_end)
    model.where(metric_date: range_start..range_end, calculation_version: calculation_version).to_a
  end

  def observation(player_id:, metric_key:, value:, sample_size:, numerator:, denominator:, components: nil, dimension_type: "", dimension_value: "")
    definition = METRICS.fetch(metric_key)
    {
      player_id: player_id,
      metric_key: metric_key,
      metric_group: definition.fetch(:group),
      display_name: definition.fetch(:label),
      directionality: definition.fetch(:direction),
      unit: definition.fetch(:unit),
      dimension_type: dimension_type,
      dimension_value: dimension_value,
      value: round(value),
      sample_size: sample_size.to_i,
      numerator: numerator.to_f,
      denominator: denominator.to_f,
      components: components
    }
  end

  def rate_observation(player_id, metric_key, numerator, denominator, scale: 1, dimension_type: "", dimension_value: "")
    return if denominator.to_f <= 0

    observation(
      player_id: player_id,
      metric_key: metric_key,
      value: numerator.to_f / denominator * scale,
      sample_size: denominator.to_i,
      numerator: numerator.to_f * scale,
      denominator: denominator,
      dimension_type: dimension_type,
      dimension_value: dimension_value
    )
  end

  def grouped_observations(rows)
    rows.group_by { |row| [ row[:metric_key], row[:dimension_type], row[:dimension_value] ] }
  end

  def peer_groups(rows)
    groups = [ [ "mlb", "all", rows ] ]
    if rows.first[:metric_group] == "batting"
      rows.group_by { |row| position_by_player[row[:player_id]] }.each do |position, peers|
        groups << [ "position", position, peers ] if position.present?
      end
    else
      rows.group_by { |row| pitcher_role_by_player[row[:player_id]] }.each do |role, peers|
        groups << [ "pitcher_role", role, peers ] if role.present?
      end
    end
    groups
  end

  def create_benchmark!(identity, peer_group_type, peer_group_key, peers)
    metric_key, dimension_type, dimension_value = identity
    definition = METRICS.fetch(metric_key)
    LeagueMetricBenchmark.create!(
      metric_key: metric_key,
      metric_group: definition.fetch(:group),
      display_name: definition.fetch(:label),
      peer_group_type: peer_group_type,
      peer_group_key: peer_group_key,
      dimension_type: dimension_type,
      dimension_value: dimension_value,
      directionality: definition.fetch(:direction),
      average_value: benchmark_average(metric_key, peers),
      sample_size: peers.sum { |row| row[:sample_size] },
      player_count: peers.length,
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: calculation_version,
      calculated_at: calculated_at,
      source_name: SOURCE_NAME,
      metadata: { unit: definition.fetch(:unit), average_method: metric_key == "ops" ? "pooled_rate" : "sample_weighted" }
    )
  end

  def create_percentiles!(benchmark, peers, previous)
    values = peers.map { |row| row[:value] }
    peers.each do |row|
      previous_row = previous[observation_identity(row)]
      change_value = previous_row ? round(row[:value] - previous_row[:value]) : nil
      change_percentage = previous_row && !previous_row[:value].zero? ? round(change_value / previous_row[:value].abs * 100) : nil

      PlayerMetricPercentile.create!(
        player_id: row[:player_id],
        league_metric_benchmark: benchmark,
        raw_value: row[:value],
        percentile: percentile(row[:value], values, benchmark.directionality),
        previous_value: previous_row&.dig(:value),
        change_value: change_value,
        change_percentage: change_percentage,
        sample_size: row[:sample_size],
        peer_player_count: peers.length,
        source_start_date: start_date,
        source_end_date: end_date,
        previous_start_date: previous_start_date,
        previous_end_date: previous_end_date,
        calculation_version: calculation_version,
        calculated_at: calculated_at,
        source_name: SOURCE_NAME,
        metadata: { unit: row[:unit], dimension_type: row[:dimension_type], dimension_value: row[:dimension_value] }
      )
    end
    peers.length
  end

  def benchmark_average(metric_key, peers)
    return pooled_ops(peers) if metric_key == "ops"

    denominator = peers.sum { |row| row[:denominator] }
    return 0 if denominator.zero?

    round(peers.sum { |row| row[:numerator] } / denominator)
  end

  def pooled_ops(peers)
    totals = peers.each_with_object(Hash.new(0.0)) do |row, values|
      row.fetch(:components).each { |key, value| values[key] += value.to_f }
    end
    ops(totals)
  end

  def ops(totals)
    at_bats = totals.fetch("at_bats").to_f
    hits = totals.fetch("hits").to_f
    walks = totals.fetch("walks").to_f
    return 0 if at_bats.zero?

    total_bases = hits + totals.fetch("doubles").to_f + (2 * totals.fetch("triples").to_f) + (3 * totals.fetch("home_runs").to_f)
    obp_denominator = at_bats + walks
    obp = obp_denominator.zero? ? 0 : (hits + walks) / obp_denominator
    obp + (total_bases / at_bats)
  end

  def percentile(value, values, directionality)
    strict = if directionality == "lower_better"
      values.count { |peer| peer > value }
    else
      values.count { |peer| peer < value }
    end
    equal = values.count { |peer| peer == value }
    round((strict + (equal * 0.5)) * 100.0 / values.length, 2)
  end

  def position_by_player
    @position_by_player ||= begin
      current = PlayerPosition.current.primary_assignments
        .joins(:position).pluck(:player_id, "positions.abbreviation").to_h
      seasonal = PlayerPosition.for_season(end_date.year).primary_assignments
        .joins(:position).pluck(:player_id, "positions.abbreviation").to_h
      current.merge(seasonal)
    end
  end

  def pitcher_role_by_player
    @pitcher_role_by_player ||= begin
      rows = daily_rows(PlayerPitchingDaily, start_date, end_date)
      rows.group_by(&:player_id).to_h do |player_id, player_rows|
        games = sum_metric(player_rows, "games")
        starts = sum_metric(player_rows, "games_started")
        role = games.zero? ? nil : (starts.positive? && starts * 2 >= games ? "starter" : "reliever")
        [ player_id, role ]
      end
    end
  end

  def sum_metrics(rows, keys)
    keys.to_h { |key| [ key, sum_metric(rows, key) ] }
  end

  def sum_metric(rows, key, fallback: nil)
    rows.sum do |row|
      value = row.metrics[key]
      value = row.metrics[fallback] if value.nil? && fallback
      value.to_f
    end
  end

  def weighted_metric_sum(rows, metric_key, sample_key, fallback: nil)
    rows.sum do |row|
      sample = row.metrics[sample_key]
      sample = row.metrics[fallback] if sample.nil? && fallback
      row.metrics[metric_key].to_f * sample.to_f
    end
  end

  def weighted_percentage_sum(rows, metric_key, sample_key)
    weighted_metric_sum(rows, metric_key, sample_key) / 100.0
  end

  def observation_identity(row)
    [ row[:player_id], row[:metric_key], row[:dimension_type], row[:dimension_value] ]
  end

  def remove_existing!
    benchmarks = LeagueMetricBenchmark.where(
      source_start_date: start_date,
      source_end_date: end_date,
      calculation_version: calculation_version
    )
    PlayerMetricPercentile.where(league_metric_benchmark_id: benchmarks.select(:id)).delete_all
    benchmarks.delete_all
  end

  def period_length
    (end_date - start_date).to_i + 1
  end

  def previous_start_date
    start_date - period_length.days
  end

  def previous_end_date
    start_date - 1.day
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "Benchmark dates must be valid ISO dates"
  end

  def round(value, precision = 6)
    value.to_f.round(precision)
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
