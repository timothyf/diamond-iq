class PlayerPitchingDaily < ApplicationRecord
  include DailyAnalyticalSummary

  self.table_name = "player_pitching_daily"

  belongs_to :player
  belongs_to :team
end
