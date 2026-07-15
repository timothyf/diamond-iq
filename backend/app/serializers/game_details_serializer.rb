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
      batting_lines: batting_lines,
      pitching_lines: pitching_lines,
      lineups: lineups,
      plate_appearances: plate_appearances
    }
  end

  private

  attr_reader :game

  def batting_lines
    game.game_player_batting_lines.sort_by { |line| [ line.home ? 1 : 0, line.batting_order || 9999 ] }.map do |line|
      line.attributes.except("raw_data").merge("player" => player_json(line.player), "team" => team_json(line.team))
    end
  end

  def pitching_lines
    game.game_player_pitching_lines.sort_by { |line| [ line.home ? 1 : 0, line.appearance_order || 999 ] }.map do |line|
      line.attributes.except("raw_data").merge("player" => player_json(line.player), "team" => team_json(line.team))
    end
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
