class DailyAnalyticsRefreshJob < ApplicationJob
  queue_as :default

  def perform(start_date:, end_date: nil, calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION)
    result = DailyAnalyticsRefresh.call(
      start_date: start_date,
      end_date: end_date,
      calculation_version: calculation_version
    )
    raise result[:message] unless result[:success]

    result
  end
end
