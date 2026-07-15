class TeamProfileSnapshotQuery
  GAME_LIMIT = 5

  def initialize(team:, season: nil, on: Date.current)
    @team = team
    @requested_season = season
    @on = on
  end

  def result
    {
      season: season,
      available_seasons: available_seasons,
      record: record,
      roster: roster_memberships.map { |membership| serialize_membership(membership) },
      roster_summary: roster_summary,
      recent_games: recent_games.map { |game| GameSerializer.call(game) },
      upcoming_games: upcoming_games.map { |game| GameSerializer.call(game) },
      source_metadata: source_metadata
    }
  end

  private

  attr_reader :team, :requested_season, :on

  def season
    @season ||= Integer(requested_season, exception: false) || stored_seasons.max || on.year
  end

  def available_seasons
    @available_seasons ||= (stored_seasons + [ season ]).uniq.sort
  end

  def stored_seasons
    @stored_seasons ||= team_games.joins(:schedule).distinct.order("schedules.season").pluck("schedules.season")
  end

  def team_games
    @team_games ||= Game.for_team(team)
  end

  def season_games
    @season_games ||= team_games
      .joins(:schedule)
      .where(schedules: { season: season })
      .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
  end

  def completed_games
    @completed_games ||= season_games.where.not(home_score: nil, away_score: nil).to_a
  end

  def record
    totals = completed_games.each_with_object({ wins: 0, losses: 0, ties: 0, runs_scored: 0, runs_allowed: 0 }) do |game, sum|
      team_score, opponent_score = scores_for(game)
      sum[:runs_scored] += team_score
      sum[:runs_allowed] += opponent_score

      if team_score > opponent_score
        sum[:wins] += 1
      elsif team_score < opponent_score
        sum[:losses] += 1
      else
        sum[:ties] += 1
      end
    end

    totals.merge(games_played: completed_games.length, winning_percentage: winning_percentage(totals))
  end

  def scores_for(game)
    game.home_team_id == team.id ? [ game.home_score, game.away_score ] : [ game.away_score, game.home_score ]
  end

  def winning_percentage(totals)
    decisions = totals[:wins] + totals[:losses]
    return nil if decisions.zero?

    (totals[:wins].to_f / decisions).round(3)
  end

  def recent_games
    season_games
      .where("official_date <= ?", on)
      .where.not(home_score: nil, away_score: nil)
      .order(official_date: :desc, scheduled_at: :desc, mlb_id: :desc)
      .limit(GAME_LIMIT)
      .to_a
  end

  def upcoming_games
    season_games
      .where("official_date >= ?", on)
      .where(home_score: nil, away_score: nil)
      .order(:official_date, :scheduled_at, :mlb_id)
      .limit(GAME_LIMIT)
      .to_a
  end

  def roster_memberships
    @roster_memberships ||= team.team_memberships
      .active_on(on)
      .includes(player: [ :profile, { player_positions: :position } ])
      .to_a
      .group_by(&:player_id)
      .values
      .map { |memberships| memberships.min_by { |membership| [ MlbRosterStatus.priority(membership.roster_status), -membership.starts_on.jd, membership.id ] } }
      .sort_by { |membership| [ membership.primary_position.to_s, membership.player.last_name, membership.player.first_name ] }
  end

  def serialize_membership(membership)
    player = membership.player
    profile = player.profile
    position = membership.primary_position.presence || current_primary_position(player)&.abbreviation

    {
      id: membership.id,
      roster_status: membership.roster_status,
      status_description: membership.source_status_description,
      injured: membership.injured?,
      jersey_number: membership.jersey_number,
      primary_position: position,
      starts_on: membership.starts_on,
      last_synced_at: membership.last_synced_at,
      player: {
        id: player.id,
        mlb_id: player.mlb_id,
        full_name: player.full_name,
        first_name: player.first_name,
        last_name: player.last_name,
        headshot_url: profile&.headshot_url
      }
    }
  end

  def current_primary_position(player)
    player.player_positions.find { |assignment| assignment.season.nil? && assignment.is_primary? }&.position
  end

  def roster_summary
    {
      total: roster_memberships.length,
      active: roster_memberships.count { |membership| membership.roster_status == "active" },
      injured: roster_memberships.count(&:injured?),
      other: roster_memberships.count { |membership| membership.roster_status != "active" && !membership.injured? }
    }
  end

  def source_metadata
    game_sync = team_games.maximum(:last_synced_at)
    roster_sync = team.team_memberships.maximum(:last_synced_at)

    {
      last_updated_at: [ game_sync, roster_sync, team.updated_at ].compact.max,
      schedule_last_synced_at: game_sync,
      roster_last_synced_at: roster_sync,
      sources: [ ("MLB Stats API" if game_sync.present? || roster_sync.present?) ].compact
    }
  end
end
