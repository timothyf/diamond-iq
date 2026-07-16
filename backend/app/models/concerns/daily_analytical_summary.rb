module DailyAnalyticalSummary
  extend ActiveSupport::Concern

  included do
    scope :for_version, ->(version) { where(calculation_version: version) }
    scope :between, ->(start_date, end_date) { where(metric_date: start_date..end_date) }

    validates :metric_date, :source_start_date, :source_end_date,
      :calculation_version, :calculated_at, :source_name, presence: true
    validates :sample_size, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validate :source_range_is_valid
  end

  private

  def source_range_is_valid
    return if source_start_date.blank? || source_end_date.blank? || source_end_date >= source_start_date

    errors.add(:source_end_date, "must be on or after source start date")
  end
end
