class RemovePreviousPeriodChangeFromPlayerMetricPercentiles < ActiveRecord::Migration[7.1]
  def change
    remove_columns :player_metric_percentiles,
      :previous_value,
      :change_value,
      :change_percentage,
      :previous_start_date,
      :previous_end_date
  end
end
