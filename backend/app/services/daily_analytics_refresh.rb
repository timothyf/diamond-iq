class DailyAnalyticsRefresh
  CALCULATION_VERSION = "1.0.0"
  SOURCE_NAME = "DiamondIQ daily analytics"
  SUMMARY_MODELS = [
    PlayerBattingDaily,
    PlayerPitchingDaily,
    PitcherPitchTypeDaily,
    BatterSplitSummary,
    PitcherSplitSummary,
    TeamDailyMetric
  ].freeze

  def self.call(start_date: nil, end_date: nil, dates: nil, calculation_version: CALCULATION_VERSION)
    new(
      start_date: start_date,
      end_date: end_date,
      dates: dates,
      calculation_version: calculation_version
    ).call
  end

  def initialize(start_date: nil, end_date: nil, dates: nil, calculation_version: CALCULATION_VERSION)
    @start_date = start_date
    @end_date = end_date
    @dates = dates
    @calculation_version = calculation_version.to_s.strip
  end

  def call
    calculation_dates = normalized_dates
    return failure("At least one calculation date is required") if calculation_dates.empty?
    return failure("Calculation version is required") if calculation_version.blank?

    totals = SUMMARY_MODELS.to_h { |model| [ model.table_name, 0 ] }
    calculation_dates.each do |date|
      counts = DailyAnalyticsCalculator.call(metric_date: date, calculation_version: calculation_version)
      counts.each { |table, count| totals[table] += count }
    end

    {
      success: true,
      message: "Refreshed daily analytics for #{calculation_dates.length} #{'date'.pluralize(calculation_dates.length)}",
      data: {
        calculation_version: calculation_version,
        source_start_date: calculation_dates.min.iso8601,
        source_end_date: calculation_dates.max.iso8601,
        calculated_date_count: calculation_dates.length,
        row_counts: totals
      }
    }
  rescue ArgumentError => error
    failure(error.message)
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to refresh daily analytics: #{error.message}")
  end

  private

  attr_reader :start_date, :end_date, :dates, :calculation_version

  def normalized_dates
    values = if dates.present?
      Array(dates)
    elsif start_date.present?
      first = parse_date(start_date)
      last = end_date.present? ? parse_date(end_date) : first
      raise ArgumentError, "End date must be on or after start date" if last < first

      (first..last).to_a
    else
      []
    end

    values.filter_map { |value| parse_date(value) }.uniq.sort
  end

  def parse_date(value)
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "Analytics dates must be valid ISO dates"
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
