class PlateAppearance < ApplicationRecord
  belongs_to :game
  belongs_to :batter, class_name: "Player", optional: true
  belongs_to :pitcher, class_name: "Player", optional: true
  belongs_to :batting_team, class_name: "Team", optional: true
  belongs_to :fielding_team, class_name: "Team", optional: true
  has_many :pitches, class_name: "PitchDatum", dependent: :nullify, inverse_of: :plate_appearance

  validates :at_bat_index, :plate_appearance_number, presence: true
  validates :at_bat_index, uniqueness: { scope: :game_id }
  validates :plate_appearance_number, uniqueness: { scope: :game_id }
  validates :source_name, :last_synced_at, presence: true
end
