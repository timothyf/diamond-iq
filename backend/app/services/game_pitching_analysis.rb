class GamePitchingAnalysis
  SWING_DESCRIPTIONS = %w[
    swinging_strike swinging_strike_blocked missed_bunt foul foul_bunt foul_tip
    hit_into_play hit_into_play_no_out hit_into_play_score
  ].freeze
  WHIFF_DESCRIPTIONS = %w[swinging_strike swinging_strike_blocked missed_bunt].freeze
  CALLED_STRIKE_DESCRIPTIONS = %w[called_strike].freeze
  STRIKE_DESCRIPTIONS = (SWING_DESCRIPTIONS + CALLED_STRIKE_DESCRIPTIONS).freeze

  def self.call(game)
    new(game).result
  end

  def initialize(game)
    @game = game
  end

  def result
    pitching_lines.map { |line| analyze(line) }
  end

  private

  attr_reader :game

  def analyze(line)
    pitches = pitches_by_pitcher.fetch(line.player.mlb_id, [])
    appearances = appearances_by_pitcher.fetch(line.player_id, [])
    pitch_count = line.pitches.presence || pitches.length
    strike_count = line.strikes.nil? ? pitches.count { |pitch| strike?(pitch) } : line.strikes
    swings = pitches.count { |pitch| swing?(pitch) }
    whiffs = pitches.count { |pitch| whiff?(pitch) }
    called_strikes = pitches.count { |pitch| called_strike?(pitch) }
    first_pitches = pitches.group_by(&:at_bat_number).values.map do |plate_appearance_pitches|
      plate_appearance_pitches.min_by(&:pitch_number)
    end
    chase_opportunities = pitches.count { |pitch| chase_opportunity?(pitch) }
    velocities = pitches.filter_map { |pitch| pitch.release_speed&.to_f }

    {
      player: player_json(line.player),
      team: team_json(line.team),
      home: line.home,
      starter: line.starter,
      appearance_order: line.appearance_order,
      innings_pitched: line.innings_pitched,
      decision: line.decision,
      pitch_data_available: pitches.any?,
      pitch_count: pitch_count,
      analyzed_pitch_count: pitches.length,
      strike_count: strike_count,
      strike_percentage: percentage(strike_count, pitch_count),
      first_pitch_strikes: first_pitches.count { |pitch| strike?(pitch) },
      first_pitch_opportunities: first_pitches.length,
      first_pitch_strike_percentage: percentage(first_pitches.count { |pitch| strike?(pitch) }, first_pitches.length),
      swings: swings,
      whiffs: whiffs,
      whiff_percentage: percentage(whiffs, swings),
      called_strikes: called_strikes,
      csw_count: called_strikes + whiffs,
      csw_percentage: percentage(called_strikes + whiffs, pitches.length),
      average_velocity: average(velocities),
      maximum_velocity: velocities.max&.round(1),
      chase_opportunities: chase_opportunities,
      chases: pitches.count { |pitch| chase?(pitch) },
      chase_percentage: percentage(pitches.count { |pitch| chase?(pitch) }, chase_opportunities),
      batters_faced: line.batters_faced.presence || appearances.length,
      pitch_usage: pitch_usage(pitches),
      times_through_order: times_through_order(pitches, appearances)
    }
  end

  def pitch_usage(pitches)
    pitches.group_by { |pitch| pitch.pitch_type.presence || "UN" }.map do |pitch_type, rows|
      velocities = rows.filter_map { |pitch| pitch.release_speed&.to_f }
      exit_velocities = rows.filter_map { |pitch| pitch.launch_speed&.to_f if DailyAnalyticsCalculator.batted_ball?(pitch) }
      swings = rows.count { |pitch| swing?(pitch) }
      whiffs = rows.count { |pitch| whiff?(pitch) }
      called_strikes = rows.count { |pitch| called_strike?(pitch) }
      {
        pitch_type: pitch_type,
        pitch_name: rows.filter_map(&:pitch_name).first || (pitch_type == "UN" ? "Unknown" : pitch_type),
        count: rows.length,
        percentage: percentage(rows.length, pitches.length),
        average_velocity: average(velocities),
        maximum_velocity: velocities.max&.round(1),
        swings: swings,
        whiffs: whiffs,
        whiff_percentage: percentage(whiffs, swings),
        called_strikes: called_strikes,
        csw_count: called_strikes + whiffs,
        csw_percentage: percentage(called_strikes + whiffs, rows.length),
        batted_balls: exit_velocities.length,
        average_exit_velocity: average(exit_velocities)
      }
    end.sort_by { |usage| [-usage.fetch(:count), usage.fetch(:pitch_type)] }
  end

  def times_through_order(pitches, appearances)
    pitch_appearances = pitches.group_by(&:at_bat_number).values.map do |rows|
      rows.min_by(&:pitch_number)
    end
    explicit_turns = pitch_appearances.filter_map do |pitch|
      turn = pitch.n_thruorder_pitcher.to_i
      turn if turn.positive?
    end

    counts = if explicit_turns.any?
      explicit_turns.tally
    else
      appearances.each_slice(9).map.with_index(1).to_h { |rows, turn| [turn, rows.length] }
    end

    {
      maximum: counts.keys.max,
      plate_appearances: counts.sort.map { |turn, count| { time: turn, batters_faced: count } }
    }
  end

  def pitching_lines
    @pitching_lines ||= game.game_player_pitching_lines.includes(:player, :team)
      .order(:home, :appearance_order, :id).to_a
  end

  def pitches_by_pitcher
    @pitches_by_pitcher ||= game.pitches.order(:at_bat_number, :pitch_number).to_a.group_by(&:pitcher)
  end

  def appearances_by_pitcher
    @appearances_by_pitcher ||= game.plate_appearances.order(:at_bat_index).to_a.group_by(&:pitcher_id)
  end

  def swing?(pitch)
    DailyAnalyticsCalculator.swing?(pitch)
  end

  def whiff?(pitch)
    DailyAnalyticsCalculator.whiff?(pitch)
  end

  def called_strike?(pitch)
    CALLED_STRIKE_DESCRIPTIONS.include?(DailyAnalyticsCalculator.description_key(pitch.description))
  end

  def strike?(pitch)
    STRIKE_DESCRIPTIONS.include?(DailyAnalyticsCalculator.description_key(pitch.description))
  end

  def chase_opportunity?(pitch)
    pitch.zone.present? && !pitch.zone.to_i.between?(1, 9)
  end

  def chase?(pitch)
    chase_opportunity?(pitch) && swing?(pitch)
  end

  def percentage(numerator, denominator)
    return if denominator.to_i.zero?

    ((numerator.to_f / denominator) * 100).round(1)
  end

  def average(values)
    return if values.empty?

    (values.sum / values.length.to_f).round(1)
  end

  def player_json(player)
    { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name }
  end

  def team_json(team)
    { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
  end
end
