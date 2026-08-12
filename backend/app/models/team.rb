class Team < ApplicationRecord
  has_many :need_profiles, dependent: :destroy
  has_many :players, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :membership_players, through: :team_memberships, source: :player
  has_many :rosters, dependent: :destroy
  has_many :roster_snapshots, dependent: :destroy
  has_many :home_games, class_name: "Game", foreign_key: :home_team_id, inverse_of: :home_team, dependent: :restrict_with_error
  has_many :away_games, class_name: "Game", foreign_key: :away_team_id, inverse_of: :away_team, dependent: :restrict_with_error
  has_many :game_player_batting_lines, dependent: :restrict_with_error
  has_many :game_player_pitching_lines, dependent: :restrict_with_error
  has_many :lineup_entries, dependent: :restrict_with_error
  has_many :player_batting_daily, dependent: :restrict_with_error
  has_many :player_pitching_daily, dependent: :restrict_with_error
  has_many :pitcher_pitch_type_daily, dependent: :nullify
  has_many :batter_split_summaries, dependent: :nullify
  has_many :pitcher_split_summaries, dependent: :nullify
  has_many :team_daily_metrics, dependent: :restrict_with_error
  has_many :opponent_reports, dependent: :destroy
  has_many :lineup_scenarios, dependent: :destroy
  has_many :reports_as_opponent, class_name: "OpponentReport", foreign_key: :opponent_team_id,
    inverse_of: :opponent_team, dependent: :restrict_with_error

  def logo_url
    "#{NineLensConfig.fetch(:external_services, :mlb_assets, :static_base_url)}/team-logos/#{mlb_id}.svg"
  end

  validates :mlb_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :abbreviation, presence: true
  validates :team_name, presence: true
  validates :location_name, presence: true
  validates :short_name, presence: true
  validates :team_code, presence: true
  validates :file_code, presence: true
end
