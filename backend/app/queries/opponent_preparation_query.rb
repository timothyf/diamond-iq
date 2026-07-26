class OpponentPreparationQuery
  RECENT_GAME_LIMIT = 10
  REPERTOIRE_PITCH_LIMIT = 500
  CHANGE_WINDOW = 100
  SWING_DESCRIPTIONS = DailyAnalyticsCalculator::SWING_DESCRIPTIONS
  WHIFF_DESCRIPTIONS = DailyAnalyticsCalculator::WHIFF_DESCRIPTIONS

  def initialize(team:, upcoming_games:, season:, on: Date.current)
    @team = team
    @upcoming_games = upcoming_games
    @season = season
    @on = on
  end

  def result
    return empty_result if series_games.empty?

    {
      opponent: serialize_team(opponent),
      recent_performance: recent_performance,
      probable_starters: opponent_starters.map { |pitcher| pitcher_report(pitcher) }
    }
  end

  private

  attr_reader :team, :upcoming_games, :season, :on

  def empty_result
    { opponent: nil, recent_performance: nil, probable_starters: [] }
  end

  def series_games
    @series_games ||= begin
      first = upcoming_games.first
      if first
        opponent_id = opponent_for(first)&.id
        upcoming_games.take_while { |game| opponent_for(game)&.id == opponent_id }
      else
        []
      end
    end
  end

  def opponent
    @opponent ||= opponent_for(series_games.first)
  end

  def opponent_for(game)
    game.home_team_id == team.id ? game.away_team : game.home_team
  end

  def opponent_starters
    series_games.filter_map do |game|
      game.home_team_id == opponent.id ? game.home_probable_pitcher : game.away_probable_pitcher
    end.uniq(&:id)
  end

  def recent_performance
    scope = TeamDailyMetric.where(metric_date: Date.new(season, 1, 1)..on)
    calculation_version = scope.order(calculated_at: :desc).pick(:calculation_version)
    rows = scope
      .where(team_id: opponent.id, calculation_version: calculation_version)
      .order(metric_date: :desc)
      .limit(RECENT_GAME_LIMIT)
      .to_a
    return { games: 0, wins: 0, losses: 0, runs_per_game: nil, ops: nil, era: nil } if rows.empty?

    totals = rows.each_with_object(Hash.new(0.0)) do |row, sum|
      %w[games wins losses runs_scored at_bats hits doubles triples home_runs walks hit_by_pitch sacrifice_flies
         pitching_outs_recorded pitching_earned_runs].each { |key| sum[key] += row.metrics[key].to_f }
    end
    games = totals["games"].to_i
    obp_denominator = totals.values_at("at_bats", "walks", "hit_by_pitch", "sacrifice_flies").sum
    total_bases = totals["hits"] + totals["doubles"] + (2 * totals["triples"]) + (3 * totals["home_runs"])
    obp = ratio(totals["hits"] + totals["walks"] + totals["hit_by_pitch"], obp_denominator)
    slugging = ratio(total_bases, totals["at_bats"])

    {
      games: games,
      wins: totals["wins"].to_i,
      losses: totals["losses"].to_i,
      runs_per_game: ratio(totals["runs_scored"], games),
      ops: obp && slugging ? round(obp + slugging) : nil,
      era: totals["pitching_outs_recorded"].positive? ? round(totals["pitching_earned_runs"] * 27 / totals["pitching_outs_recorded"]) : nil
    }
  end

  def pitcher_report(pitcher)
    pitches = PitchDatum
      .where(pitcher: pitcher.mlb_id, game_date: Date.new(season, 1, 1)..on)
      .where.not(pitch_type: nil)
      .includes(:game, :plate_appearance)
      .order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc)
      .limit(REPERTOIRE_PITCH_LIMIT)
      .to_a
    current = pitches.first(CHANGE_WINDOW)
    previous = pitches.drop(CHANGE_WINDOW).first(CHANGE_WINDOW)

    {
      player: serialize_player(pitcher),
      throws: pitches.filter_map(&:p_throws).tally.max_by(&:last)&.first,
      sample_size: pitches.length,
      repertoire: repertoire(pitches),
      handedness_splits: handedness_splits(pitches),
      recent_changes: recent_changes(current, previous),
      evidence: evidence(pitches.first(5))
    }
  end

  def repertoire(pitches)
    pitches.group_by(&:pitch_type).sort_by { |_type, rows| -rows.length }.first(6).map do |pitch_type, rows|
      {
        pitch_type: pitch_type,
        pitch_name: rows.filter_map(&:pitch_name).first || pitch_type,
        count: rows.length,
        usage_percentage: percentage(rows.length, pitches.length),
        average_velocity: average(rows.filter_map(&:release_speed)),
        horizontal_break: average(rows.filter_map { |pitch| pitch.pfx_x && pitch.pfx_x * 12 }),
        vertical_break: average(rows.filter_map { |pitch| pitch.pfx_z && pitch.pfx_z * 12 }),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def handedness_splits(pitches)
    %w[L R].map do |hand|
      rows = pitches.select { |pitch| pitch.stand == hand }
      swings = rows.count { |pitch| SWING_DESCRIPTIONS.include?(pitch.description.to_s.downcase) }
      appearances = rows.map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
      strikeouts = rows.select { |pitch| DailyAnalyticsCalculator::STRIKEOUT_EVENTS.include?(pitch.events.to_s.downcase) }
        .map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
      {
        batter_hand: hand,
        pitches: rows.length,
        plate_appearances: appearances,
        strikeout_rate: percentage(strikeouts, appearances),
        whiff_rate: percentage(rows.count { |pitch| WHIFF_DESCRIPTIONS.include?(pitch.description.to_s.downcase) }, swings),
        evidence: evidence(rows.first(2))
      }
    end
  end

  def recent_changes(current, previous)
    return [] if current.empty? || previous.empty?

    changes = []
    velocity_change = difference(average(current.filter_map(&:release_speed)), average(previous.filter_map(&:release_speed)))
    if velocity_change
      changes << {
        key: "velocity",
        label: "Average velocity",
        change: velocity_change,
        unit: "mph",
        evidence: evidence(current.first(2))
      }
    end

    current.group_by(&:pitch_type).sort_by { |_type, rows| -rows.length }.first(3).each do |pitch_type, rows|
      change = difference(percentage(rows.length, current.length), percentage(previous.count { |pitch| pitch.pitch_type == pitch_type }, previous.length))
      next if change.nil?

      changes << {
        key: "usage_#{pitch_type}",
        label: "#{rows.first.pitch_name || pitch_type} usage",
        change: change,
        unit: "percentage_points",
        evidence: evidence(rows.first(2))
      }
    end
    changes
  end

  def evidence(pitches)
    pitches.filter_map do |pitch|
      next unless pitch.game_id && pitch.plate_appearance_id

      {
        game_id: pitch.game_id,
        game_date: pitch.game_date,
        pitch_id: pitch.id,
        plate_appearance_id: pitch.plate_appearance_id,
        pitch_name: pitch.pitch_name || pitch.pitch_type,
        velocity: pitch.release_speed,
        result: pitch.description
      }
    end
  end

  def serialize_team(value)
    { id: value.id, mlb_id: value.mlb_id, name: value.name, abbreviation: value.abbreviation }
  end

  def serialize_player(value)
    { id: value.id, mlb_id: value.mlb_id, full_name: value.full_name }
  end

  def average(values)
    values.empty? ? nil : round(values.sum.to_f / values.length)
  end

  def ratio(numerator, denominator)
    denominator.to_f.positive? ? numerator.to_f / denominator : nil
  end

  def percentage(numerator, denominator)
    value = ratio(numerator, denominator)
    value && round(value * 100)
  end

  def difference(current, previous)
    current && previous ? round(current - previous) : nil
  end

  def round(value)
    value.to_f.round(2)
  end
end
