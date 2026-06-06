class Player < ApplicationRecord
  belongs_to :team
  has_many :player_season_stats, dependent: :destroy

  validates :mlb_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
end
