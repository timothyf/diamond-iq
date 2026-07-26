class LineupScenario < ApplicationRecord
  belongs_to :team
  has_many :entries, class_name: "LineupScenarioEntry", dependent: :destroy, inverse_of: :lineup_scenario

  validates :season, :scenario_date, :name, presence: true
  validates :season, numericality: { only_integer: true, greater_than: 1800 }
end
