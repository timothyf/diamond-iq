class Position < ApplicationRecord
  POSITION_TYPES = %w[pitcher catcher infielder outfielder designated_hitter two_way other].freeze

  has_many :player_positions, dependent: :restrict_with_error
  has_many :players, through: :player_positions

  before_validation :normalize_identifiers

  validates :mlb_code, presence: true, uniqueness: { case_sensitive: false }
  validates :abbreviation, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :position_type, presence: true, inclusion: { in: POSITION_TYPES }
  validates :sort_order, presence: true, numericality: { only_integer: true, greater_than: 0 }

  scope :ordered, -> { order(:sort_order, :id) }

  private

  def normalize_identifiers
    self.mlb_code = mlb_code.to_s.strip.upcase.presence
    self.abbreviation = abbreviation.to_s.strip.upcase.presence
  end
end
