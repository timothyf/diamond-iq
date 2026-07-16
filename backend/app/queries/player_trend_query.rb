class PlayerTrendQuery
  MAX_POINTS = 120
  SWING_DESCRIPTIONS = DailyAnalyticsCalculator::SWING_DESCRIPTIONS
  WHIFF_DESCRIPTIONS = DailyAnalyticsCalculator::WHIFF_DESCRIPTIONS
  PITCH_COLUMNS = %i[
    game_date game_pk at_bat_number pitch_number pitch_type pitch_name description zone
    release_speed launch_speed
  ].freeze

  def initialize(player:, analysis_range:)
    @player = player
    @analysis_range = analysis_range
  end

  def result
    {
      range: analysis_range.to_h,
      summary: period_summary,
      batting: batting_trends,
      pitching: pitching_trends
    }
  end

  private

  attr_reader :player, :analysis_range

  def period_summary
    current = summary_for(analysis_range.start_date, analysis_range.end_date)
    previous = summary_for(analysis_range.previous_start_date, analysis_range.previous_end_date)
    {
      current: current,
      previous: previous,
      changes: {
        batting: changes(current[:batting], previous[:batting]),
        pitching: changes(current[:pitching], previous[:pitching])
      }
    }
  end

  def summary_for(start_date, end_date)
    batter_rows = pitch_rows(:batter, start_date, end_date)
    pitcher_rows = pitch_rows(:pitcher, start_date, end_date)
    batted_balls = batter_rows.select { |pitch| pitch.launch_speed.present? }
    batter_swings = batter_rows.count { |pitch| swing?(pitch) }
    batter_chase_opportunities = batter_rows.count { |pitch| chase_opportunity?(pitch) }
    pitcher_swings = pitcher_rows.count { |pitch| swing?(pitch) }
    pitcher_chase_opportunities = pitcher_rows.count { |pitch| chase_opportunity?(pitch) }
    velocities = pitcher_rows.filter_map { |pitch| pitch.release_speed&.to_f }

    {
      batting: {
        plate_appearances: plate_appearance_count(batter_rows),
        pitches_seen: batter_rows.length,
        batted_balls: batted_balls.length,
        average_exit_velocity: average(batted_balls.filter_map { |pitch| pitch.launch_speed&.to_f }),
        hard_hit_percentage: percentage(batted_balls.count { |pitch| pitch.launch_speed >= 95 }, batted_balls.length),
        whiff_percentage: percentage(batter_rows.count { |pitch| whiff?(pitch) }, batter_swings),
        chase_percentage: percentage(batter_rows.count { |pitch| chase?(pitch) }, batter_chase_opportunities)
      },
      pitching: {
        pitch_count: pitcher_rows.length,
        average_velocity: average(velocities),
        whiff_percentage: percentage(pitcher_rows.count { |pitch| whiff?(pitch) }, pitcher_swings),
        chase_percentage: percentage(pitcher_rows.count { |pitch| chase?(pitch) }, pitcher_chase_opportunities)
      }
    }
  end

  def batting_trends
    rows = pitch_rows(:batter, analysis_range.start_date, analysis_range.end_date)
    appearances = rows.group_by { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.values
      .sort_by { |group| pitch_order(group.first) }
    points = sampled_indices(appearances.length).map do |index|
      window = appearances[[ index - analysis_range.plate_appearance_window + 1, 0 ].max..index].flatten
      batted_balls = window.select { |pitch| pitch.launch_speed.present? }
      swings = window.count { |pitch| swing?(pitch) }
      chase_opportunities = window.count { |pitch| chase_opportunity?(pitch) }
      {
        date: appearances[index].first.game_date,
        sequence: index + 1,
        window_sample_size: [ index + 1, analysis_range.plate_appearance_window ].min,
        average_exit_velocity: average(batted_balls.filter_map { |pitch| pitch.launch_speed&.to_f }),
        exit_velocity_sample_size: batted_balls.length,
        hard_hit_percentage: percentage(batted_balls.count { |pitch| pitch.launch_speed >= 95 }, batted_balls.length),
        whiff_percentage: percentage(window.count { |pitch| whiff?(pitch) }, swings),
        chase_percentage: percentage(window.count { |pitch| chase?(pitch) }, chase_opportunities)
      }
    end

    {
      window_type: "plate_appearances",
      window_size: analysis_range.plate_appearance_window,
      total_observations: appearances.length,
      charts: [
        chart("exit_velocity", "Exit velocity", "mph", points, "average_exit_velocity", "exit_velocity_sample_size"),
        chart("hard_hit_rate", "Hard-hit rate", "percent", points, "hard_hit_percentage"),
        chart("batter_whiff_rate", "Whiff rate", "percent", points, "whiff_percentage"),
        chart("batter_chase_rate", "Chase rate", "percent", points, "chase_percentage")
      ]
    }
  end

  def pitching_trends
    rows = pitch_rows(:pitcher, analysis_range.start_date, analysis_range.end_date)
    pitch_types = rows.group_by(&:pitch_type).sort_by { |_type, pitches| -pitches.length }
      .filter_map { |type, _pitches| type.presence }.first(4)
    points = sampled_indices(rows.length).map do |index|
      window = rows[[ index - analysis_range.pitch_window + 1, 0 ].max..index]
      swings = window.count { |pitch| swing?(pitch) }
      chase_opportunities = window.count { |pitch| chase_opportunity?(pitch) }
      velocities = window.filter_map { |pitch| pitch.release_speed&.to_f }
      usage = pitch_types.to_h do |pitch_type|
        [ pitch_type, percentage(window.count { |pitch| pitch.pitch_type == pitch_type }, window.length) ]
      end
      {
        date: rows[index].game_date,
        sequence: index + 1,
        window_sample_size: [ index + 1, analysis_range.pitch_window ].min,
        average_velocity: average(velocities),
        velocity_sample_size: velocities.length,
        whiff_percentage: percentage(window.count { |pitch| whiff?(pitch) }, swings),
        chase_percentage: percentage(window.count { |pitch| chase?(pitch) }, chase_opportunities),
        usage: usage
      }
    end

    usage_series = pitch_types.map do |pitch_type|
      series(pitch_type, pitch_type, points) { |point| point[:usage][pitch_type] }
    end
    {
      window_type: "pitches",
      window_size: analysis_range.pitch_window,
      total_observations: rows.length,
      charts: [
        chart("pitch_velocity", "Pitch velocity", "mph", points, "average_velocity", "velocity_sample_size"),
        chart("pitcher_whiff_rate", "Whiff rate", "percent", points, "whiff_percentage"),
        chart("pitcher_chase_rate", "Chase rate", "percent", points, "chase_percentage"),
        { key: "pitch_usage", title: "Pitch usage", unit: "percent", series: usage_series }
      ]
    }
  end

  def chart(key, title, unit, points, value_key, sample_key = "window_sample_size")
    {
      key: key,
      title: title,
      unit: unit,
      series: [ series(key, title, points, sample_key) { |point| point[value_key.to_sym] } ]
    }
  end

  def series(key, label, points, sample_key = "window_sample_size")
    {
      key: key,
      label: label,
      points: points.filter_map do |point|
        value = yield(point)
        next if value.nil?

        {
          date: point[:date],
          sequence: point[:sequence],
          value: value,
          sample_size: point[sample_key.to_sym] || point[:window_sample_size]
        }
      end
    }
  end

  def pitch_scope(role, start_date, end_date)
    PitchDatum.where(role => player.mlb_id, game_date: start_date..end_date)
      .where.not(game_date: nil)
      .select(*PITCH_COLUMNS)
      .order(:game_date, :game_pk, :at_bat_number, :pitch_number)
  end

  def pitch_rows(role, start_date, end_date)
    @pitch_rows ||= {}
    @pitch_rows[[ role, start_date, end_date ]] ||= pitch_scope(role, start_date, end_date).to_a
  end

  def pitch_order(pitch)
    [ pitch.game_date, pitch.game_pk, pitch.at_bat_number, pitch.pitch_number ]
  end

  def sampled_indices(count)
    return [] if count.zero?
    return (0...count).to_a if count <= MAX_POINTS

    step = (count - 1).to_f / (MAX_POINTS - 1)
    (0...MAX_POINTS).map { |index| (index * step).round }.uniq
  end

  def plate_appearance_count(rows)
    rows.map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
  end

  def changes(current, previous)
    current.to_h do |key, value|
      previous_value = previous[key]
      change = value.nil? || previous_value.nil? ? nil : (value - previous_value).round(4)
      [ key, { current: value, previous: previous_value, change: change } ]
    end
  end

  def swing?(pitch)
    SWING_DESCRIPTIONS.include?(pitch.description.to_s.downcase)
  end

  def whiff?(pitch)
    WHIFF_DESCRIPTIONS.include?(pitch.description.to_s.downcase)
  end

  def chase_opportunity?(pitch)
    pitch.zone.present? && !pitch.zone.to_i.between?(1, 9)
  end

  def chase?(pitch)
    chase_opportunity?(pitch) && swing?(pitch)
  end

  def average(values)
    return if values.empty?

    (values.sum / values.length.to_f).round(4)
  end

  def percentage(numerator, denominator)
    return if denominator.zero?

    (numerator.to_f / denominator * 100).round(4)
  end
end
