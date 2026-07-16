class PlayerBattingDaily < ApplicationRecord
  include DailyAnalyticalSummary

  self.table_name = "player_batting_daily"

  belongs_to :player
  belongs_to :team
end
