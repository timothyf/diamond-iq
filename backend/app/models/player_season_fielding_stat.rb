class PlayerSeasonFieldingStat < ApplicationRecord
  belongs_to :player
  belongs_to :team, optional: true

  validates :season, :team_abbreviation, :position, :source_name, :last_synced_at, presence: true
  validates :games, :putouts, :assists, :fielding_errors, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :innings, :fielding_percentage, :defensive_runs_saved, :outs_above_average, numericality: true, allow_nil: true
end
