class OpponentReportGenerator
  UPCOMING_GAME_LIMIT = 5

  def self.call(team:, season:, on: Date.current)
    new(team: team, season: season, on: on).call
  end

  def initialize(team:, season:, on:)
    @team = team
    @season = Integer(season)
    @on = on
  end

  def call
    preparation = OpponentPreparationQuery.new(
      team: team,
      upcoming_games: upcoming_games,
      season: season,
      on: on
    ).result
    opponent_id = preparation.dig(:opponent, :id)
    raise ArgumentError, "No upcoming opponent is available for this season." unless opponent_id

    games = series_games(opponent_id)
    opponent = Team.find(opponent_id)
    generated_at = Time.current

    OpponentReport.create!(
      team: team,
      opponent_team: opponent,
      season: season,
      series_starts_on: games.first.official_date,
      series_ends_on: games.last.official_date,
      title: "#{team.abbreviation} vs #{opponent.abbreviation} · #{series_label(games)}",
      generated_at: generated_at,
      snapshot: {
        generated_at: generated_at,
        team: serialize_team(team),
        opponent: serialize_team(opponent),
        series: games.map { |game| GameSerializer.call(game) },
        recent_performance: preparation.fetch(:recent_performance),
        probable_starters: preparation.fetch(:probable_starters)
      }
    )
  end

  private

  attr_reader :team, :season, :on

  def upcoming_games
    @upcoming_games ||= Game.for_team(team)
      .joins(:schedule)
      .where(schedules: { season: season })
      .where("official_date >= ?", on)
      .where(home_score: nil, away_score: nil)
      .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
      .order(:official_date, :scheduled_at, :mlb_id)
      .limit(UPCOMING_GAME_LIMIT)
      .to_a
  end

  def series_games(opponent_id)
    upcoming_games.take_while do |game|
      [ game.home_team_id, game.away_team_id ].include?(opponent_id)
    end
  end

  def series_label(games)
    first = games.first.official_date.strftime("%b %-d")
    last = games.last.official_date.strftime("%b %-d, %Y")
    games.first.official_date == games.last.official_date ? last : "#{first}–#{last}"
  end

  def serialize_team(value)
    { id: value.id, mlb_id: value.mlb_id, name: value.name, abbreviation: value.abbreviation }
  end
end
