class StatType < ApplicationRecord
  has_many :player_season_stats, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :category }
  validates :label, presence: true
  validates :category, presence: true
end
