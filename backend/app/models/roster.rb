class Roster < ApplicationRecord
  belongs_to :team

  has_many :roster_players, dependent: :destroy
  has_many :players, through: :roster_players

  validates :season, presence: true, numericality: { only_integer: true }
  validates :team_id, uniqueness: { scope: :season }
end