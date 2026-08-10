class GameBattedBallAnalysis
  HARD_HIT_THRESHOLD = 95.0
  BARREL_CLASSIFICATION = 6
  LEADER_LIMIT = 3

  def self.call(game)
    new(game).result
  end

  def initialize(game)
    @game = game
  end

  def result
    [ game.away_team, game.home_team ].map do |team|
      team_contacts = contacts.select { |pitch| batting_team_id(pitch) == team.id }
      metrics(team_contacts).merge(
        team: team_json(team),
        home: team.id == game.home_team_id,
        leaders: leaders(team_contacts)
      )
    end
  end

  private

  attr_reader :game

  def contacts
    @contacts ||= game.pitches
      .includes(plate_appearance: [ :batter, :batting_team ])
      .where.not(launch_speed: nil)
      .order(:at_bat_number, :pitch_number)
      .to_a
      .select { |pitch| DailyAnalyticsCalculator.batted_ball?(pitch) }
  end

  def batting_team_id(pitch)
    pitch.plate_appearance&.batting_team_id || batter_context.fetch(pitch.batter, {})[:team_id]
  end

  def batter(pitch)
    pitch.plate_appearance&.batter || batter_context.fetch(pitch.batter, {})[:player]
  end

  def batter_context
    @batter_context ||= game.game_player_batting_lines.includes(:player).each_with_object({}) do |line, context|
      context[line.player.mlb_id] = { player: line.player, team_id: line.team_id }
    end
  end

  def leaders(team_contacts)
    team_contacts.group_by { |pitch| batter(pitch) }.filter_map do |player, player_contacts|
      next if player.nil?

      metrics(player_contacts).merge(player: player_json(player))
    end.sort_by do |entry|
      [ -entry.fetch(:batted_balls), -(entry.fetch(:estimated_woba) || -1), entry.dig(:player, :full_name) ]
    end.first(LEADER_LIMIT)
  end

  def metrics(rows)
    exit_velocities = values(rows, :launch_speed)
    launch_angles = values(rows, :launch_angle)
    expected_woba = values(rows, :estimated_woba_using_speedangle)
    hard_hit_count = exit_velocities.count { |velocity| velocity >= HARD_HIT_THRESHOLD }
    barrel_count = rows.count { |pitch| pitch.launch_speed_angle == BARREL_CLASSIFICATION }
    distribution = rows.each_with_object(Hash.new(0)) { |pitch, counts| counts[batted_ball_type(pitch)] += 1 }

    {
      batted_balls: rows.length,
      average_exit_velocity: average(exit_velocities),
      maximum_exit_velocity: exit_velocities.max&.round(1),
      hard_hit_count: hard_hit_count,
      hard_hit_percentage: percentage(hard_hit_count, exit_velocities.length),
      average_launch_angle: average(launch_angles),
      estimated_woba: average(expected_woba, precision: 3),
      barrel_count: barrel_count,
      barrel_percentage: percentage(barrel_count, rows.length),
      distribution: %i[ground_ball line_drive fly_ball].to_h do |type|
        count = distribution[type]
        [ type, { count: count, percentage: percentage(count, rows.length) } ]
      end
    }
  end

  def batted_ball_type(pitch)
    normalized = pitch.bb_type.to_s.downcase.tr(" -", "_")
    return :ground_ball if %w[ground_ball groundball ground].include?(normalized)
    return :line_drive if %w[line_drive linedrive line].include?(normalized)
    return :fly_ball if %w[fly_ball flyball fly pop_up popup].include?(normalized)

    angle = pitch.launch_angle&.to_f
    return :unknown if angle.nil?
    return :ground_ball if angle < 10
    return :line_drive if angle < 25

    :fly_ball
  end

  def values(rows, field)
    rows.filter_map { |row| row.public_send(field)&.to_f }
  end

  def average(numbers, precision: 1)
    return if numbers.empty?

    (numbers.sum / numbers.length.to_f).round(precision)
  end

  def percentage(numerator, denominator)
    return if denominator.to_i.zero?

    ((numerator.to_f / denominator) * 100).round(1)
  end

  def player_json(player)
    { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name }
  end

  def team_json(team)
    { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
  end
end
