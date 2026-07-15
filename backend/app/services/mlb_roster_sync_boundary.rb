class MlbRosterSyncBoundary
  def self.call(season:, today: Date.current)
    normalized_season = Integer(season, exception: false)
    raise ArgumentError, "Season must be greater than 1800" if normalized_season.nil? || normalized_season <= 1800
    raise ArgumentError, "Season cannot be in the future" if normalized_season > today.year

    normalized_season == today.year ? today : Date.new(normalized_season, 12, 31)
  end
end
