class PlayerStat < ApplicationRecord
  validates :player_id, presence: true
  validates :source_url, presence: true
  validates :row_number, presence: true
  validates :stats_data, presence: true
end
