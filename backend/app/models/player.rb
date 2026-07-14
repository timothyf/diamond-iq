class Player < ApplicationRecord
  belongs_to :team
  has_one :profile, class_name: "PlayerProfile", dependent: :destroy, inverse_of: :player
  has_many :player_season_stats, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :membership_teams, through: :team_memberships, source: :team
  has_many :player_positions, dependent: :destroy
  has_many :positions, through: :player_positions
  has_many :roster_players, dependent: :destroy
  has_many :rosters, through: :roster_players
  has_many :home_probable_pitcher_games, class_name: "Game", foreign_key: :home_probable_pitcher_id, dependent: :nullify
  has_many :away_probable_pitcher_games, class_name: "Game", foreign_key: :away_probable_pitcher_id, dependent: :nullify

  validates :mlb_id, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    [first_name, last_name].compact.join(" ")
  end

  def primary_position(season: nil)
    player_positions.includes(:position).find_by(season: season, is_primary: true)&.position
  end
end
