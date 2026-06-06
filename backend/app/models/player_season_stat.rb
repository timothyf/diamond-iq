class PlayerSeasonStat < ApplicationRecord
  belongs_to :player
  belongs_to :stat_type

  validates :season, presence: true
  validates :value, presence: true, numericality: true
end
