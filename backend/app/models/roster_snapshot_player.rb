class RosterSnapshotPlayer < ApplicationRecord
  belongs_to :roster_snapshot
  belongs_to :player, optional: true

  validates :mlb_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :mlb_id, uniqueness: { scope: :roster_snapshot_id }
  validates :full_name, presence: true
end
