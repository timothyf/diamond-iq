class LineupScenarioEntry < ApplicationRecord
  DEFENSIVE_POSITIONS = %w[C 1B 2B 3B SS LF CF RF DH].freeze

  belongs_to :lineup_scenario, inverse_of: :entries
  belongs_to :player

  validates :batting_slot, inclusion: { in: 1..9 }
  validates :defensive_position, inclusion: { in: DEFENSIVE_POSITIONS }
  validates :player_id, uniqueness: { scope: :lineup_scenario_id }
  validates :batting_slot, uniqueness: { scope: :lineup_scenario_id }
end
