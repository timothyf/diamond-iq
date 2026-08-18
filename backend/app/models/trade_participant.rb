class TradeParticipant < ApplicationRecord
  belongs_to :trade, inverse_of: :trade_participants
  belongs_to :player, optional: true
  belongs_to :from_team, class_name: "Team", optional: true
  belongs_to :to_team, class_name: "Team", optional: true

  validates :player_mlb_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :player_mlb_id, uniqueness: { scope: :trade_id }
  validates :player_name, presence: true
end
