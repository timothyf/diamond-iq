class MlbRosterSyncBoundary
  def self.call(season:, today: Date.current, team_mlb_id: nil)
    normalized_season = Integer(season, exception: false)
    raise ArgumentError, "Season must be greater than 1800" if normalized_season.nil? || normalized_season <= 1800
    raise ArgumentError, "Season cannot be in the future" if normalized_season > today.year

    return today if normalized_season == today.year

    games = Game.joins(:schedule).where(schedules: { season: normalized_season }, game_type: "R")
    if team_mlb_id.present?
      team = Team.find_by(mlb_id: team_mlb_id)
      games = games.where("games.home_team_id = :team_id OR games.away_team_id = :team_id", team_id: team.id) if team
    end

    games.maximum(:official_date) || Date.new(normalized_season, 12, 31)
  end
end
