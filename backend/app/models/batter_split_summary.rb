class BatterSplitSummary < ApplicationRecord
  include DailyAnalyticalSummary

  belongs_to :player
  belongs_to :team, optional: true

  validates :split_type, :split_value, presence: true
end
