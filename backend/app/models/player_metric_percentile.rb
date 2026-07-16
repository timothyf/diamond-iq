class PlayerMetricPercentile < ApplicationRecord
  belongs_to :player
  belongs_to :league_metric_benchmark

  validates :raw_value, numericality: true
  validates :percentile, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :sample_size, :peer_player_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :source_start_date, :source_end_date, :calculation_version,
    :calculated_at, :source_name, presence: true

  scope :for_version, ->(version) { where(calculation_version: version) }
end
