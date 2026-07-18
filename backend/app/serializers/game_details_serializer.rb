class GameDetailsSerializer
  def self.call(game)
    new(game).as_json
  end

  def initialize(game)
    @game = game
  end

  def as_json
    {
      synchronized: game.details_last_synced_at.present?,
      source_url: game.details_source_url,
      last_synced_at: game.details_last_synced_at,
      line_score: line_score,
      insights: insights,
      key_performers: key_performers,
      scoring_plays: scoring_plays,
      pitching_analysis: GamePitchingAnalysis.call(game),
      batting_lines: batting_lines,
      pitching_lines: pitching_lines,
      lineups: lineups,
      plate_appearances: plate_appearances
    }
  end

  private

  attr_reader :game

  HIT_EVENTS = %w[single double triple home_run].freeze
  NON_AT_BAT_EVENTS = %w[
    walk intent_walk intentional_walk hit_by_pitch sac_bunt sac_fly
    sac_fly_double_play catcher_interf catcher_interference
  ].freeze

  def line_score
    @line_score ||= begin
      payload = game.live_feed_raw_data.dig("liveData", "linescore") || {}

      {
        current_inning: payload["currentInning"],
        current_inning_ordinal: payload["currentInningOrdinal"],
        inning_state: payload["inningState"],
        innings: Array(payload["innings"]).map do |inning|
          {
            number: inning["num"],
            ordinal: inning["ordinalNum"],
            away: line_score_side(inning["away"]),
            home: line_score_side(inning["home"])
          }
        end,
        totals: {
          away: line_score_side(payload.dig("teams", "away"), runs: game.away_score),
          home: line_score_side(payload.dig("teams", "home"), runs: game.home_score)
        }
      }
    end
  end

  def line_score_side(payload, runs: nil)
    data = payload || {}
    {
      runs: data.key?("runs") ? data["runs"] : runs,
      hits: data["hits"],
      errors: data["errors"],
      left_on_base: data["leftOnBase"]
    }
  end

  def scoring_plays
    previous_away_score = 0
    previous_home_score = 0

    plate_appearance_records.filter_map do |appearance|
      away_score = appearance.away_score.nil? ? previous_away_score : appearance.away_score
      home_score = appearance.home_score.nil? ? previous_home_score : appearance.home_score
      runs_scored = [away_score - previous_away_score, 0].max + [home_score - previous_home_score, 0].max
      previous_away_score = away_score
      previous_home_score = home_score
      next unless runs_scored.positive?

      {
        id: appearance.id,
        plate_appearance_number: appearance.plate_appearance_number,
        inning: appearance.inning,
        half_inning: appearance.half_inning,
        inning_label: scoring_inning_label(appearance),
        event: appearance.event,
        event_type: appearance.event_type,
        description: scoring_play_description(appearance, runs_scored),
        runs_scored: runs_scored,
        runs_batted_in: appearance.runs_batted_in,
        away_score: away_score,
        home_score: home_score,
        batter: player_json(appearance.batter),
        batting_team: team_json(appearance.batting_team)
      }
    end
  end

  def scoring_inning_label(appearance)
    half = appearance.half_inning.to_s.downcase == "top" ? "Top" : "Bottom"
    inning = appearance.inning
    inning.present? ? "#{half} #{inning.ordinalize}" : half
  end

  def scoring_play_description(appearance, runs_scored)
    return appearance.description if appearance.description.present?

    player_name = appearance.batter&.full_name || "A batter"
    "#{player_name} scored #{runs_scored} #{'run'.pluralize(runs_scored)}."
  end

  def batting_lines
    @batting_lines ||= game.game_player_batting_lines.sort_by { |line| [ line.home ? 1 : 0, line.batting_order || 9999 ] }.map do |line|
      rates = line.raw_data.dig("seasonStats", "batting") || {}
      line.attributes.except("raw_data").merge(
        "batting_average" => decimal_value(rates["avg"]) || line.batting_average,
        "on_base_percentage" => decimal_value(rates["obp"]) || line.on_base_percentage,
        "slugging_percentage" => decimal_value(rates["slg"]) || line.slugging_percentage,
        "ops" => decimal_value(rates["ops"]) || line.ops,
        "player" => player_json(line.player),
        "team" => team_json(line.team)
      )
    end
  end

  def pitching_lines
    @pitching_lines ||= game.game_player_pitching_lines.sort_by { |line| [ line.home ? 1 : 0, line.appearance_order || 999 ] }.map do |line|
      rates = line.raw_data.dig("seasonStats", "pitching") || {}
      line.attributes.except("raw_data").merge(
        "era" => decimal_value(rates["era"]) || line.era,
        "whip" => decimal_value(rates["whip"]) || line.whip,
        "player" => player_json(line.player),
        "team" => team_json(line.team)
      )
    end
  end

  def decimal_value(value)
    BigDecimal(value.to_s, exception: false)
  end

  def insights
    {
      decisions: {
        winning_pitcher: pitching_decision("W"),
        losing_pitcher: pitching_decision("L"),
        save: pitching_decision("S")
      },
      teams: {
        away: team_insights("away", home: false, score: game.away_score, opponent_score: game.home_score),
        home: team_insights("home", home: true, score: game.home_score, opponent_score: game.away_score)
      }
    }
  end

  def key_performers
    {
      top_hitters: {
        away: top_hitter(home: false),
        home: top_hitter(home: true)
      },
      most_impactful_pitcher: most_impactful_pitcher,
      power_hitters: power_hitters,
      scoreless_relievers: scoreless_relievers,
      top_run_producers: top_run_producers
    }
  end

  def top_hitter(home:)
    line = batting_line_records.select { |candidate| candidate.home == home }
      .max_by { |candidate| batting_impact_key(candidate) }
    batting_performer(line)
  end

  def batting_impact_key(line)
    [
      batting_impact_score(line),
      total_bases(line),
      line.hits.to_i,
      line.walks.to_i,
      -line.strikeouts.to_i,
      -(line.batting_order || 9999)
    ]
  end

  def batting_impact_score(line)
    total_bases(line) + line.walks.to_i + (line.runs_batted_in.to_i * 2) + line.runs.to_i
  end

  def total_bases(line)
    singles = line.hits.to_i - line.doubles.to_i - line.triples.to_i - line.home_runs.to_i
    singles + (line.doubles.to_i * 2) + (line.triples.to_i * 3) + (line.home_runs.to_i * 4)
  end

  def most_impactful_pitcher
    line = pitching_line_records.max_by do |candidate|
      [pitching_impact_score(candidate), candidate.outs_recorded.to_i, candidate.strikeouts.to_i]
    end
    pitching_performer(line)
  end

  def pitching_impact_score(line)
    decision_bonus = case decision_code(line.decision)
    when "W" then 6
    when "S" then 5
    when "H" then 2
    else 0
    end

    line.outs_recorded.to_i + (line.strikeouts.to_i * 2) + decision_bonus -
      (line.earned_runs.to_i * 4) - line.hits.to_i - line.walks.to_i - (line.home_runs.to_i * 2)
  end

  def power_hitters
    batting_line_records.select do |line|
      line.home_runs.to_i.positive? || extra_base_hits(line) >= 2
    end.sort_by do |line|
      [-line.home_runs.to_i, -extra_base_hits(line), -total_bases(line), line.player.full_name]
    end.map { |line| batting_performer(line, highlight: power_summary(line)) }
  end

  def scoreless_relievers
    pitching_line_records.select do |line|
      !line.starter && line.outs_recorded.to_i.positive? && line.runs.to_i.zero?
    end.sort_by do |line|
      [-line.outs_recorded.to_i, -line.strikeouts.to_i, line.player.full_name]
    end.map { |line| pitching_performer(line, highlight: scoreless_relief_summary(line)) }
  end

  def top_run_producers
    eligible = batting_line_records.select { |line| runs_responsible_for(line).positive? }
    maximum = eligible.map { |line| runs_responsible_for(line) }.max
    return [] if maximum.nil?

    eligible.select { |line| runs_responsible_for(line) == maximum }
      .sort_by { |line| [line.home ? 1 : 0, line.player.full_name] }
      .map do |line|
        batting_performer(
          line,
          highlight: "#{runs_responsible_for(line)} #{'run'.pluralize(runs_responsible_for(line))} produced · #{line.runs.to_i} R, #{line.runs_batted_in.to_i} RBI"
        )
      end
  end

  def runs_responsible_for(line)
    line.runs.to_i + line.runs_batted_in.to_i - line.home_runs.to_i
  end

  def extra_base_hits(line)
    line.doubles.to_i + line.triples.to_i + line.home_runs.to_i
  end

  def batting_performer(line, highlight: nil)
    return if line.nil?

    {
      player: player_json(line.player),
      team: team_json(line.team),
      home: line.home,
      summary: highlight || batting_summary(line),
      metrics: {
        at_bats: line.at_bats,
        runs: line.runs,
        hits: line.hits,
        doubles: line.doubles,
        triples: line.triples,
        home_runs: line.home_runs,
        runs_batted_in: line.runs_batted_in,
        walks: line.walks,
        total_bases: total_bases(line),
        runs_responsible_for: runs_responsible_for(line)
      }
    }
  end

  def pitching_performer(line, highlight: nil)
    return if line.nil?

    {
      player: player_json(line.player),
      team: team_json(line.team),
      home: line.home,
      summary: highlight || pitching_summary(line),
      metrics: {
        starter: line.starter,
        innings_pitched: line.innings_pitched,
        outs_recorded: line.outs_recorded,
        runs: line.runs,
        earned_runs: line.earned_runs,
        hits: line.hits,
        walks: line.walks,
        strikeouts: line.strikeouts,
        home_runs: line.home_runs,
        decision: line.decision
      }
    }
  end

  def batting_summary(line)
    parts = ["#{line.hits.to_i}-for-#{line.at_bats.to_i}"]
    parts << "#{line.home_runs.to_i} HR" if line.home_runs.to_i.positive?
    parts << "#{line.runs_batted_in.to_i} RBI" if line.runs_batted_in.to_i.positive?
    parts << "#{line.runs.to_i} R" if line.runs.to_i.positive?
    parts.join(", ")
  end

  def pitching_summary(line)
    parts = ["#{line.innings_pitched.presence || '0.0'} IP", "#{line.earned_runs.to_i} ER", "#{line.strikeouts.to_i} K"]
    parts << decision_code(line.decision) if decision_code(line.decision).present?
    parts.join(", ")
  end

  def power_summary(line)
    parts = []
    parts << "#{line.home_runs.to_i} HR" if line.home_runs.to_i.positive?
    parts << "#{extra_base_hits(line)} XBH" if extra_base_hits(line) >= 2
    parts.join(" · ")
  end

  def scoreless_relief_summary(line)
    "#{line.innings_pitched.presence || '0.0'} scoreless IP · #{line.strikeouts.to_i} K"
  end

  def batting_line_records
    @batting_line_records ||= game.game_player_batting_lines.includes(:player, :team).to_a
  end

  def pitching_line_records
    @pitching_line_records ||= game.game_player_pitching_lines.includes(:player, :team).to_a
  end

  def pitching_decision(code)
    line = game.game_player_pitching_lines.find do |candidate|
      decision_code(candidate.decision) == code
    end
    return if line.nil?

    {
      player: player_json(line.player),
      decision: line.decision
    }
  end

  def decision_code(value)
    value.to_s.delete("()").strip.split(/[\s,]/).first
  end

  def team_insights(side, home:, score:, opponent_score:)
    stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "batting") || {}
    fielding_stats = game.boxscore_raw_data.dig("teams", side, "teamStats", "fielding") || {}
    lines = game.game_player_batting_lines.select { |line| line.home == home }
    totals = line_score.fetch(:totals).fetch(side.to_sym)
    risp = risp_performance(home)

    {
      run_differential: score.nil? || opponent_score.nil? ? nil : score - opponent_score,
      hits: integer_stat(stats, "hits") || totals[:hits] || sum_lines(lines, :hits),
      errors: totals[:errors] || integer_stat(fielding_stats, "errors"),
      walks: integer_stat(stats, "baseOnBalls") || sum_lines(lines, :walks),
      strikeouts: integer_stat(stats, "strikeOuts") || sum_lines(lines, :strikeouts),
      home_runs: integer_stat(stats, "homeRuns") || sum_lines(lines, :home_runs),
      left_on_base: totals[:left_on_base] || integer_stat(stats, "leftOnBase"),
      runners_in_scoring_position: risp
    }
  end

  def risp_performance(home)
    appearances = game.plate_appearances.select do |appearance|
      appearance.batting_team_id == (home ? game.home_team_id : game.away_team_id) &&
        appearance.raw_data.dig("matchup", "splits", "menOnBase") == "RISP"
    end

    {
      hits: appearances.count { |appearance| HIT_EVENTS.include?(appearance.event_type) },
      at_bats: appearances.count do |appearance|
        appearance.complete? && appearance.event_type.present? && !NON_AT_BAT_EVENTS.include?(appearance.event_type)
      end
    }
  end

  def integer_stat(stats, key)
    Integer(stats[key], exception: false)
  end

  def sum_lines(lines, field)
    lines.sum { |line| line.public_send(field).to_i }
  end

  def lineups
    game.lineup_entries.group_by(&:team).map do |team, entries|
      {
        team: team_json(team),
        entries: entries.sort_by { |entry| entry.batting_order || 9999 }.map do |entry|
          entry.attributes.except("raw_data").merge("player" => player_json(entry.player))
        end
      }
    end
  end

  def plate_appearances
    plate_appearance_records.map do |appearance|
      appearance.attributes.except("raw_data").merge(
        "batter" => player_json(appearance.batter),
        "pitcher" => player_json(appearance.pitcher),
        "batting_team" => team_json(appearance.batting_team),
        "fielding_team" => team_json(appearance.fielding_team),
        "pitches" => appearance.pitches.sort_by(&:pitch_number).map { |pitch| pitch_json(pitch) }
      )
    end
  end

  def plate_appearance_records
    @plate_appearance_records ||= game.plate_appearances
      .includes(:batter, :pitcher, :batting_team, :fielding_team, :pitches)
      .sort_by(&:at_bat_index)
  end

  def pitch_json(pitch)
    pitch.attributes.slice(
      "id", "game_id", "plate_appearance_id", "at_bat_number", "pitch_number",
      "pitcher", "batter", "pitch_type", "pitch_name", "description", "events",
      "release_speed", "release_spin_rate", "plate_x", "plate_z", "zone",
      "launch_speed", "launch_angle", "estimated_woba_using_speedangle"
    )
  end

  def player_json(player)
    return if player.nil?

    { id: player.id, mlb_id: player.mlb_id, full_name: player.full_name }
  end

  def team_json(team)
    return if team.nil?

    { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
  end
end
