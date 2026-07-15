class GamePlayerBattingLine < ApplicationRecord
  belongs_to :game
  belongs_to :player
  belongs_to :team
  belongs_to :opponent_team, class_name: "Team"

  validates :player_id, uniqueness: { scope: :game_id }
  validates :source_name, :last_synced_at, presence: true
end
