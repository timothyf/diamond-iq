class PitcherPitchTypeDaily < ApplicationRecord
  include DailyAnalyticalSummary

  self.table_name = "pitcher_pitch_type_daily"

  belongs_to :player
  belongs_to :team, optional: true

  validates :pitch_type, presence: true
end
