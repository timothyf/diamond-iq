class PlayerPosition < ApplicationRecord
  belongs_to :player
  belongs_to :position

  validates :position_id, uniqueness: { scope: [:player_id, :season] }
  validates :season, numericality: { only_integer: true, greater_than: 1800 }, allow_nil: true
  validates :source_name, presence: true
  validates :last_synced_at, presence: true
  validate :only_one_primary_position_per_scope

  scope :current, -> { where(season: nil) }
  scope :for_season, ->(season) { where(season: season) }
  scope :primary_assignments, -> { where(is_primary: true) }
  scope :secondary_assignments, -> { where(is_primary: false) }
  scope :ordered, -> {
    joins(:position).order(
      Arel.sql("player_positions.season DESC NULLS FIRST"),
      Arel.sql("player_positions.is_primary DESC"),
      Arel.sql("positions.sort_order ASC")
    )
  }

  private

  def only_one_primary_position_per_scope
    return unless is_primary? && player_id.present?

    conflicts = self.class.where(player_id: player_id, season: season, is_primary: true)
    conflicts = conflicts.where.not(id: id) if persisted?

    errors.add(:is_primary, "has already been assigned for this player and season") if conflicts.exists?
  end
end
