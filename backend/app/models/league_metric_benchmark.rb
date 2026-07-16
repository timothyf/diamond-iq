class LeagueMetricBenchmark < ApplicationRecord
  PEER_GROUP_TYPES = %w[mlb position pitcher_role].freeze
  DIRECTIONALITIES = %w[higher_better lower_better neutral].freeze

  has_many :player_metric_percentiles, dependent: :destroy

  validates :metric_key, :metric_group, :display_name, :peer_group_key,
    :calculation_version, :calculated_at, :source_name, presence: true
  validates :peer_group_type, inclusion: { in: PEER_GROUP_TYPES }
  validates :directionality, inclusion: { in: DIRECTIONALITIES }
  validates :sample_size, :player_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :average_value, numericality: true
  validate :source_range_is_valid

  scope :for_version, ->(version) { where(calculation_version: version) }

  private

  def source_range_is_valid
    return if source_start_date.blank? || source_end_date.blank? || source_end_date >= source_start_date

    errors.add(:source_end_date, "must be on or after source start date")
  end
end
