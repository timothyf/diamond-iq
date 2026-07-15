class RosterSnapshot < ApplicationRecord
  ROSTER_TYPES = %w[40Man active].freeze

  belongs_to :team
  has_many :roster_snapshot_players, dependent: :destroy

  validates :season, presence: true, numericality: { only_integer: true }
  validates :roster_type, inclusion: { in: ROSTER_TYPES }
  validates :snapshot_on, :source_name, :last_synced_at, presence: true
  validates :roster_type, uniqueness: { scope: [ :team_id, :snapshot_on ] }
end
