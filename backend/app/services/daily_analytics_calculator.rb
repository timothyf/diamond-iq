class DailyAnalyticsCalculator
  SWING_DESCRIPTIONS = %w[
    swinging_strike swinging_strike_blocked missed_bunt foul foul_bunt foul_tip
    hit_into_play hit_into_play_no_out hit_into_play_score
  ].freeze
  WHIFF_DESCRIPTIONS = %w[swinging_strike swinging_strike_blocked missed_bunt].freeze
  HIT_EVENTS = %w[single double triple home_run].freeze
  WALK_EVENTS = %w[walk intent_walk intentional_walk].freeze
  STRIKEOUT_EVENTS = %w[strikeout strikeout_double_play].freeze
  PITCH_COLUMNS = %i[
    game_pk at_bat_number pitcher batter stand p_throws pitch_type pitch_name
    description events inning_topbot release_speed release_spin_rate release_extension
    pfx_x pfx_z zone launch_speed launch_angle estimated_woba_using_speedangle delta_run_exp
  ].freeze
  BATTING_LINE_COLUMNS = %i[
    game_id player_id team_id plate_appearances at_bats runs hits doubles triples home_runs
    runs_batted_in walks strikeouts stolen_bases caught_stealing
  ].freeze
  PITCHING_LINE_COLUMNS = %i[
    game_id player_id team_id starter outs_recorded batters_faced hits runs earned_runs
    home_runs walks strikeouts pitches strikes holds saves blown_saves
  ].freeze
  MODELS = DailyAnalyticsRefresh::SUMMARY_MODELS

  def self.call(metric_date:, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    new(metric_date: metric_date, calculation_version: calculation_version).call
  end

  def initialize(metric_date:, calculation_version:)
    @metric_date = metric_date.to_date
    @calculation_version = calculation_version
    @calculated_at = Time.current
  end

  def call
    rows = {
      PlayerBattingDaily => batting_rows,
      PlayerPitchingDaily => pitching_rows,
      PitcherPitchTypeDaily => pitcher_pitch_type_rows,
      BatterSplitSummary => batter_split_rows,
      PitcherSplitSummary => pitcher_split_rows,
      TeamDailyMetric => team_rows
    }

    ApplicationRecord.transaction do
      MODELS.each { |model| model.where(metric_date: metric_date, calculation_version: calculation_version).delete_all }
      rows.each { |model, values| model.insert_all(values) if values.any? }
    end

    rows.to_h { |model, values| [ model.table_name, values.length ] }
  end

  private

  attr_reader :metric_date, :calculation_version, :calculated_at

  def batting_rows
    batting_lines.group_by { |line| [ line.player_id, line.team_id ] }.map do |(player_id, team_id), lines|
      totals = sum_fields(lines, %i[plate_appearances at_bats runs hits doubles triples home_runs runs_batted_in walks strikeouts stolen_bases caught_stealing])
      total_bases = totals[:hits] + totals[:doubles] + (2 * totals[:triples]) + (3 * totals[:home_runs])
      average = ratio(totals[:hits], totals[:at_bats])
      obp = ratio(totals[:hits] + totals[:walks], totals[:at_bats] + totals[:walks])
      slugging = ratio(total_bases, totals[:at_bats])

      common_row(sample_size: totals[:plate_appearances]).merge(
        player_id: player_id,
        team_id: team_id,
        metrics: totals.merge(
          games: lines.map(&:game_id).uniq.length,
          batting_average: average,
          on_base_percentage: obp,
          on_base_percentage_is_approximate: true,
          slugging_percentage: slugging,
          ops: round(obp + slugging)
        )
      )
    end
  end

  def pitching_rows
    pitching_lines.group_by { |line| [ line.player_id, line.team_id ] }.map do |(player_id, team_id), lines|
      totals = sum_fields(lines, %i[outs_recorded batters_faced hits runs earned_runs home_runs walks strikeouts pitches strikes holds saves blown_saves])
      innings = totals[:outs_recorded].div(3) + (totals[:outs_recorded] % 3) / 10.0

      common_row(sample_size: totals[:batters_faced].positive? ? totals[:batters_faced] : totals[:pitches]).merge(
        player_id: player_id,
        team_id: team_id,
        metrics: totals.merge(
          games: lines.map(&:game_id).uniq.length,
          games_started: lines.count(&:starter),
          innings_pitched: innings,
          strike_percentage: ratio(totals[:strikes], totals[:pitches]),
          era: totals[:outs_recorded].positive? ? round(totals[:earned_runs] * 27.0 / totals[:outs_recorded]) : nil,
          whip: totals[:outs_recorded].positive? ? round((totals[:hits] + totals[:walks]) * 3.0 / totals[:outs_recorded]) : nil
        )
      )
    end
  end

  def pitcher_pitch_type_rows
    eligible = pitches.select { |pitch| pitch.pitcher.present? && pitch.pitch_type.present? && players_by_mlb_id.key?(pitch.pitcher) }
    totals_by_pitcher = eligible.group_by(&:pitcher).transform_values(&:length)

    eligible.group_by { |pitch| [ pitch.pitcher, pitch.pitch_type ] }.map do |(mlb_id, pitch_type), grouped|
      player = players_by_mlb_id.fetch(mlb_id)
      swings = grouped.count { |pitch| swing?(pitch) }
      whiffs = grouped.count { |pitch| whiff?(pitch) }
      velocities = values(grouped, :release_speed)

      common_row(sample_size: grouped.length).merge(
        player_id: player.id,
        team_id: team_for_pitch_group(grouped, player, pitching: true),
        pitch_type: pitch_type,
        pitch_name: grouped.filter_map(&:pitch_name).first,
        metrics: {
          pitch_count: grouped.length,
          usage_percentage: percent(grouped.length, totals_by_pitcher.fetch(mlb_id)),
          average_velocity: average(velocities),
          maximum_velocity: velocities.max,
          average_spin_rate: average(values(grouped, :release_spin_rate)),
          average_extension: average(values(grouped, :release_extension)),
          average_horizontal_break: average(values(grouped, :pfx_x)),
          average_vertical_break: average(values(grouped, :pfx_z)),
          zone_percentage: percent(grouped.count { |pitch| pitch.zone.to_i.between?(1, 9) }, grouped.length),
          swings: swings,
          swing_percentage: percent(swings, grouped.length),
          whiffs: whiffs,
          whiff_percentage: percent(whiffs, swings),
          delta_run_expectancy_per_100: scaled_average(values(grouped, :delta_run_exp), 100)
        }
      )
    end
  end

  def batter_split_rows
    split_rows(:batter, batter_split_dimensions) do |grouped|
      swings = grouped.count { |pitch| swing?(pitch) }
      batted_balls = grouped.select { |pitch| pitch.launch_speed.present? }
      hard_hit = batted_balls.count { |pitch| pitch.launch_speed >= 95 }

      {
        pitches_seen: grouped.length,
        plate_appearances: plate_appearance_count(grouped),
        swings: swings,
        swing_percentage: percent(swings, grouped.length),
        whiffs: grouped.count { |pitch| whiff?(pitch) },
        whiff_percentage: percent(grouped.count { |pitch| whiff?(pitch) }, swings),
        batted_balls: batted_balls.length,
        average_exit_velocity: average(values(batted_balls, :launch_speed)),
        maximum_exit_velocity: values(batted_balls, :launch_speed).max,
        hard_hit_percentage: percent(hard_hit, batted_balls.length),
        average_launch_angle: average(values(batted_balls, :launch_angle)),
        estimated_woba: average(values(grouped, :estimated_woba_using_speedangle)),
        hits: terminal_event_count(grouped, HIT_EVENTS),
        walks: terminal_event_count(grouped, WALK_EVENTS),
        strikeouts: terminal_event_count(grouped, STRIKEOUT_EVENTS)
      }
    end
  end

  def pitcher_split_rows
    split_rows(:pitcher, pitcher_split_dimensions, pitching: true) do |grouped|
      swings = grouped.count { |pitch| swing?(pitch) }
      velocities = values(grouped, :release_speed)

      {
        pitch_count: grouped.length,
        batters_faced: plate_appearance_count(grouped),
        zone_percentage: percent(grouped.count { |pitch| pitch.zone.to_i.between?(1, 9) }, grouped.length),
        swings: swings,
        whiffs: grouped.count { |pitch| whiff?(pitch) },
        whiff_percentage: percent(grouped.count { |pitch| whiff?(pitch) }, swings),
        average_velocity: average(velocities),
        maximum_velocity: velocities.max,
        average_spin_rate: average(values(grouped, :release_spin_rate)),
        strikeouts: terminal_event_count(grouped, STRIKEOUT_EVENTS),
        walks: terminal_event_count(grouped, WALK_EVENTS),
        delta_run_expectancy_per_100: scaled_average(values(grouped, :delta_run_exp), 100)
      }
    end
  end

  def split_rows(player_field, dimensions, pitching: false)
    output = []
    dimensions.each do |split_type, value_method|
      eligible = pitches.select do |pitch|
        mlb_id = pitch.public_send(player_field)
        mlb_id.present? && players_by_mlb_id.key?(mlb_id) && value_method.call(pitch).present?
      end

      eligible.group_by { |pitch| [ pitch.public_send(player_field), value_method.call(pitch) ] }.each do |(mlb_id, split_value), grouped|
        player = players_by_mlb_id.fetch(mlb_id)
        output << common_row(sample_size: grouped.length).merge(
          player_id: player.id,
          team_id: team_for_pitch_group(grouped, player, pitching: pitching),
          split_type: split_type,
          split_value: split_value,
          metrics: yield(grouped)
        )
      end
    end
    output
  end

  def team_rows
    games.flat_map { |game| [ game.home_team_id, game.away_team_id ] }.uniq.compact.map do |team_id|
      team_games = games.select { |game| game.home_team_id == team_id || game.away_team_id == team_id }
      batting = batting_lines.select { |line| line.team_id == team_id }
      pitching = pitching_lines.select { |line| line.team_id == team_id }
      bat = sum_fields(batting, %i[plate_appearances at_bats runs hits doubles triples home_runs walks strikeouts])
      pit = sum_fields(pitching, %i[outs_recorded hits earned_runs walks strikeouts])
      total_bases = bat[:hits] + bat[:doubles] + (2 * bat[:triples]) + (3 * bat[:home_runs])
      average_value = ratio(bat[:hits], bat[:at_bats])
      obp = ratio(bat[:hits] + bat[:walks], bat[:at_bats] + bat[:walks])
      slugging = ratio(total_bases, bat[:at_bats])
      scores = team_games.filter_map { |game| team_score(game, team_id) }

      common_row(sample_size: team_games.length).merge(
        team_id: team_id,
        metrics: bat.merge(
          games: team_games.length,
          wins: scores.count { |scored, allowed| scored > allowed },
          losses: scores.count { |scored, allowed| scored < allowed },
          ties: scores.count { |scored, allowed| scored == allowed },
          runs_scored: scores.sum(&:first),
          runs_allowed: scores.sum(&:last),
          run_differential: scores.sum { |scored, allowed| scored - allowed },
          batting_average: average_value,
          on_base_percentage: obp,
          on_base_percentage_is_approximate: true,
          slugging_percentage: slugging,
          ops: round(obp + slugging),
          pitching_outs_recorded: pit[:outs_recorded],
          pitching_hits_allowed: pit[:hits],
          pitching_earned_runs: pit[:earned_runs],
          pitching_walks: pit[:walks],
          pitching_strikeouts: pit[:strikeouts],
          era: pit[:outs_recorded].positive? ? round(pit[:earned_runs] * 27.0 / pit[:outs_recorded]) : nil,
          whip: pit[:outs_recorded].positive? ? round((pit[:hits] + pit[:walks]) * 3.0 / pit[:outs_recorded]) : nil
        )
      )
    end
  end

  def common_row(sample_size:)
    {
      metric_date: metric_date,
      source_start_date: metric_date,
      source_end_date: metric_date,
      sample_size: sample_size,
      calculation_version: calculation_version,
      calculated_at: calculated_at,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      created_at: calculated_at,
      updated_at: calculated_at
    }
  end

  def batting_lines
    @batting_lines ||= GamePlayerBattingLine.joins(:game)
      .where(games: { official_date: metric_date }).select(*BATTING_LINE_COLUMNS).to_a
  end

  def pitching_lines
    @pitching_lines ||= GamePlayerPitchingLine.joins(:game)
      .where(games: { official_date: metric_date }).select(*PITCHING_LINE_COLUMNS).to_a
  end

  def games
    @games ||= Game.where(official_date: metric_date)
      .select(:id, :mlb_id, :home_team_id, :away_team_id, :home_score, :away_score).to_a
  end

  def pitches
    @pitches ||= PitchDatum.where(game_date: metric_date).select(*PITCH_COLUMNS).to_a
  end

  def players_by_mlb_id
    @players_by_mlb_id ||= Player.where(mlb_id: pitches.flat_map { |pitch| [ pitch.pitcher, pitch.batter ] }.compact.uniq).index_by(&:mlb_id)
  end

  def games_by_mlb_id
    @games_by_mlb_id ||= games.index_by(&:mlb_id)
  end

  def team_for_pitch_group(grouped, player, pitching:)
    grouped.each do |pitch|
      game = games_by_mlb_id[pitch.game_pk]
      next unless game

      top = pitch.inning_topbot.to_s.downcase.start_with?("top")
      return pitching ? (top ? game.home_team_id : game.away_team_id) : (top ? game.away_team_id : game.home_team_id)
    end
    player.team_id
  end

  def batter_split_dimensions
    {
      "pitcher_hand" => ->(pitch) { pitch.p_throws.presence&.upcase },
      "pitch_type" => ->(pitch) { pitch.pitch_type.presence },
      "home_away" => ->(pitch) { home_away(pitch, pitching: false) }
    }
  end

  def pitcher_split_dimensions
    {
      "batter_hand" => ->(pitch) { pitch.stand.presence&.upcase },
      "pitch_type" => ->(pitch) { pitch.pitch_type.presence },
      "home_away" => ->(pitch) { home_away(pitch, pitching: true) }
    }
  end

  def home_away(pitch, pitching:)
    value = pitch.inning_topbot.to_s.downcase
    return if value.blank?

    top = value.start_with?("top")
    pitching ? (top ? "home" : "away") : (top ? "away" : "home")
  end

  def team_score(game, team_id)
    return if game.home_score.nil? || game.away_score.nil?

    game.home_team_id == team_id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
  end

  def sum_fields(records, fields)
    fields.to_h { |field| [ field, records.sum { |record| record.public_send(field).to_i } ] }
  end

  def values(records, field)
    records.filter_map { |record| record.public_send(field)&.to_f }
  end

  def plate_appearance_count(grouped)
    grouped.map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
  end

  def terminal_event_count(grouped, event_names)
    grouped.select { |pitch| event_names.include?(pitch.events.to_s.downcase) }
      .map { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.uniq.length
  end

  def swing?(pitch)
    SWING_DESCRIPTIONS.include?(pitch.description.to_s.downcase)
  end

  def whiff?(pitch)
    WHIFF_DESCRIPTIONS.include?(pitch.description.to_s.downcase)
  end

  def average(numbers)
    return if numbers.empty?

    round(numbers.sum / numbers.length.to_f)
  end

  def scaled_average(numbers, scale)
    value = average(numbers)
    value.nil? ? nil : round(value * scale)
  end

  def ratio(numerator, denominator)
    denominator.to_i.zero? ? 0.0 : round(numerator.to_f / denominator)
  end

  def percent(numerator, denominator)
    round(ratio(numerator, denominator) * 100)
  end

  def round(value)
    value.to_f.round(4)
  end
end
