class Player < ApplicationRecord
  belongs_to :team
  has_many :player_season_stats, dependent: :destroy
  has_many :home_probable_pitcher_games, class_name: "Game", foreign_key: :home_probable_pitcher_id, dependent: :nullify
  has_many :away_probable_pitcher_games, class_name: "Game", foreign_key: :away_probable_pitcher_id, dependent: :nullify

  validates :mlb_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
end
