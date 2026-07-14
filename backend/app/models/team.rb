class Team < ApplicationRecord
  has_many :players, dependent: :destroy
  has_many :rosters, dependent: :destroy
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, inverse_of: :home_team, dependent: :restrict_with_error
  has_many :away_games, class_name: "Game", foreign_key: :away_team_id, inverse_of: :away_team, dependent: :restrict_with_error

  validates :mlb_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :abbreviation, presence: true
  validates :team_name, presence: true
  validates :location_name, presence: true
  validates :short_name, presence: true
  validates :team_code, presence: true
  validates :file_code, presence: true
end
