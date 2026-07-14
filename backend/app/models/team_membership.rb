class TeamMembership < ApplicationRecord
  belongs_to :player
  belongs_to :team

  validates :starts_on, presence: true
  validates :roster_status, presence: true
  validates :source_name, presence: true
  validates :last_synced_at, presence: true
  validate :ends_on_not_before_starts_on

  scope :active_on, ->(date) { where("starts_on <= ? AND (ends_on IS NULL OR ends_on >= ?)", date, date) }
  scope :current, -> { active_on(Date.current) }

  private

  def ends_on_not_before_starts_on
    return if ends_on.blank? || starts_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after starts_on")
  end
end