class PlayerIdMapping < ApplicationRecord
  SOURCE_NAME = "Chadwick Register"

  belongs_to :player, primary_key: :mlb_id, foreign_key: :mlb_id, optional: true

  validates :mlb_id, presence: true, uniqueness: true
  validates :chadwick_id, presence: true, uniqueness: true
  validates :chadwick_uuid, presence: true
  validates :source_name, presence: true
  validates :imported_at, presence: true
end
