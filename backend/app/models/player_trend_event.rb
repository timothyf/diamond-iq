class PlayerTrendEvent < ApplicationRecord
  EVENT_TYPES = %w[velocity_loss pitch_mix_change chase_rate_movement].freeze
  ROLES = %w[batter pitcher].freeze
  DIRECTIONS = %w[increase decrease].freeze
  SEVERITIES = %w[warning critical].freeze
  STATUSES = %w[active resolved].freeze

  belongs_to :player

  scope :active, -> { where(status: "active") }
  scope :recent_first, -> { order(onset_date: :desc, detected_at: :desc) }

  validates :identity_key, :metric_key, :unit, :calculation_version, presence: true
  validates :event_type, inclusion: { in: EVENT_TYPES }
  validates :role, inclusion: { in: ROLES }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :sample_size, :baseline_sample_size, numericality: { only_integer: true, greater_than: 0 }
  validates :baseline_value, :current_value, :change_value, :threshold_value,
    :baseline_start_date, :baseline_end_date, :current_start_date, :current_end_date,
    :onset_date, :detected_at, :last_observed_at, presence: true

  def resolve!(at: Time.current)
    update!(status: "resolved", resolved_at: at, last_observed_at: at)
  end
end
