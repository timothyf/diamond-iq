class TeamDailyMetric < ApplicationRecord
  include DailyAnalyticalSummary

  belongs_to :team
end
