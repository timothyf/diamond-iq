class LineupEntry < ApplicationRecord
  belongs_to :game
  belongs_to :team
  belongs_to :player

  validates :player_id, uniqueness: { scope: [ :game_id, :team_id ] }
  validates :source_name, :last_synced_at, presence: true
end
