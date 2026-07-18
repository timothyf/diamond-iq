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
    game.plate_appearances.sort_by(&:at_bat_index).map do |appearance|
      appearance.attributes.except("raw_data").merge(
        "batter" => player_json(appearance.batter),
        "pitcher" => player_json(appearance.pitcher),
        "batting_team" => team_json(appearance.batting_team),
        "fielding_team" => team_json(appearance.fielding_team),
        "pitches" => appearance.pitches.sort_by(&:pitch_number).map { |pitch| pitch_json(pitch) }
      )
    end
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
