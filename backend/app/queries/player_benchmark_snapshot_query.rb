class PlayerBenchmarkSnapshotQuery
  def initialize(player:, start_date: nil, end_date: nil, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    @player = player
    @start_date = start_date
    @end_date = end_date
    @calculation_version = calculation_version
  end

  def result
    if latest_rows.empty?
      return ContextualBenchmarkRefresh.preview(
        player_id: player.id,
        start_date: start_date,
        end_date: end_date,
        calculation_version: calculation_version
      ) if start_date.present? && end_date.present?

      return empty_result
    end

    {
      available: true,
      cached: true,
      source_start_date: latest_rows.first.source_start_date,
      source_end_date: latest_rows.first.source_end_date,
      calculation_version: calculation_version,
      calculated_at: latest_rows.map(&:calculated_at).max,
      metrics: serialized_metrics
    }
  end

  private

  attr_reader :player, :start_date, :end_date, :calculation_version

  def rows
    @rows ||= player.player_metric_percentiles
      .for_version(calculation_version)
      .includes(:league_metric_benchmark)
      .to_a
  end

  def latest_rows
    @latest_rows ||= begin
      if start_date.present? && end_date.present?
        rows.select { |row| row.source_start_date == start_date && row.source_end_date == end_date }
      else
        latest = rows.max_by { |row| [ row.source_end_date, row.source_start_date, row.calculated_at ] }
        if latest.nil?
          []
        else
          rows.select do |row|
            row.source_start_date == latest.source_start_date && row.source_end_date == latest.source_end_date
          end
        end
      end
    end
  end

  def serialized_metrics
    latest_rows.group_by do |row|
      benchmark = row.league_metric_benchmark
      [ benchmark.metric_key, benchmark.dimension_type, benchmark.dimension_value ]
    end.values.filter_map do |metric_rows|
      league = metric_rows.find { |row| row.league_metric_benchmark.peer_group_type == "mlb" }
      next if league.nil?

      position = metric_rows.find { |row| row.league_metric_benchmark.peer_group_type == "position" }
      role = metric_rows.find { |row| row.league_metric_benchmark.peer_group_type == "pitcher_role" }
      benchmark = league.league_metric_benchmark

      {
        metric_key: benchmark.metric_key,
        metric_group: benchmark.metric_group,
        display_name: benchmark.display_name,
        unit: benchmark.metadata["unit"],
        directionality: benchmark.directionality,
        dimension_type: benchmark.dimension_type.presence,
        dimension_value: benchmark.dimension_value.presence,
        raw_value: number(league.raw_value),
        mlb_average: number(benchmark.average_value),
        position_average: number(position&.league_metric_benchmark&.average_value),
        position_key: position&.league_metric_benchmark&.peer_group_key,
        pitcher_role_average: number(role&.league_metric_benchmark&.average_value),
        pitcher_role_key: role&.league_metric_benchmark&.peer_group_key,
        percentile: number(league.percentile),
        position_percentile: number(position&.percentile),
        pitcher_role_percentile: number(role&.percentile),
        sample_size: league.sample_size,
        mlb_sample_size: benchmark.sample_size,
        mlb_player_count: benchmark.player_count,
        position_player_count: position&.peer_player_count,
        pitcher_role_player_count: role&.peer_player_count
      }
    end.sort_by { |metric| [ metric[:metric_group], metric[:display_name], metric[:dimension_value].to_s ] }
  end

  def number(value)
    value&.to_f
  end

  def empty_result
    {
      available: false,
      cached: false,
      source_start_date: nil,
      source_end_date: nil,
      calculation_version: calculation_version,
      calculated_at: nil,
      metrics: []
    }
  end
end
