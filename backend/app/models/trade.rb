class Trade < ApplicationRecord
  has_many :trade_participants, dependent: :destroy, inverse_of: :trade
  has_many :players, through: :trade_participants

  validates :mlb_transaction_id, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than: 0 }
  validates :occurred_on, :description, :source_name, :last_synced_at, presence: true
end
