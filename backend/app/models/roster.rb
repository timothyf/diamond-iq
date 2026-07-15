class Roster < ApplicationRecord
  # Compatibility cache derived from TeamMembership. Do not use this model as
  # the source of historical roster truth.
  belongs_to :team

  has_many :roster_players, dependent: :destroy
  has_many :players, through: :roster_players

  validates :season, presence: true, numericality: { only_integer: true }
  validates :team_id, uniqueness: { scope: :season }
  validates :roster_type, presence: true
  validates :snapshot_on, presence: true
  validates :source_name, presence: true
  validates :last_synced_at, presence: true

  def rebuild_from_memberships!(on:, roster_type:, source_name:, last_synced_at:, raw_data: {})
    memberships = team.team_memberships.active_on(on).includes(:player)

    self.class.transaction do
      update!(
        snapshot_on: on,
        roster_type: roster_type,
        source_name: source_name,
        last_synced_at: last_synced_at,
        raw_data: raw_data
      )
      self.player_ids = memberships.map(&:player_id).uniq
    end

    self
  end
end
