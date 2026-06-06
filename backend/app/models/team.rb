class Team < ApplicationRecord
  has_many :players, dependent: :destroy

  validates :mlb_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :abbreviation, presence: true
  validates :team_name, presence: true
  validates :location_name, presence: true
  validates :short_name, presence: true
  validates :team_code, presence: true
  validates :file_code, presence: true
end
