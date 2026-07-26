class OpponentReport < ApplicationRecord
  belongs_to :team
  belongs_to :opponent_team, class_name: "Team", inverse_of: :reports_as_opponent

  validates :season, :series_starts_on, :series_ends_on, :title, :generated_at, presence: true
  validates :season, numericality: { only_integer: true, greater_than: 1800 }
  validate :series_range_is_valid

  scope :recent_first, -> { order(generated_at: :desc, id: :desc) }

  private

  def series_range_is_valid
    return if series_starts_on.blank? || series_ends_on.blank? || series_ends_on >= series_starts_on

    errors.add(:series_ends_on, "must be on or after the series start")
  end
end
