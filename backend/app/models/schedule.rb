class Schedule < ApplicationRecord
  has_many :games, dependent: :destroy

  validates :season, numericality: { only_integer: true, greater_than: 1800 }
  validates :schedule_type, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true, comparison: { greater_than_or_equal_to: :start_date }
  validates :source_name, presence: true
  validates :source_key, presence: true, uniqueness: true
  validates :last_synced_at, presence: true

  scope :for_season, ->(season) { where(season: season) }
  scope :covering, ->(date) { where("start_date <= ? AND end_date >= ?", date, date) }
end
