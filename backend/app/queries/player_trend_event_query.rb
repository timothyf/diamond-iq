class PlayerTrendEventQuery
  LIMIT = 25

  def initialize(player:, start_date: nil, end_date: nil)
    @player = player
    @start_date = start_date
    @end_date = end_date
  end

  def result
    scope = player.trend_events.recent_first
    scope = scope.where("onset_date <= ?", end_date) if end_date.present?
    scope = scope.where("current_end_date >= ? OR status = 'active'", start_date) if start_date.present?

    events = scope.limit(LIMIT).map { |event| serialize(event) }
    {
      active_count: events.count { |event| event[:status] == "active" },
      events: events
    }
  end

  private

  attr_reader :player, :start_date, :end_date

  def serialize(event)
    {
      id: event.id,
      event_type: event.event_type,
      role: event.role,
      metric_key: event.metric_key,
      pitch_type: event.pitch_type,
      direction: event.direction,
      severity: event.severity,
      status: event.status,
      unit: event.unit,
      baseline_value: event.baseline_value.to_f,
      current_value: event.current_value.to_f,
      change_value: event.change_value.to_f,
      threshold_value: event.threshold_value.to_f,
      thresholds: event.thresholds,
      baseline_sample_size: event.baseline_sample_size,
      sample_size: event.sample_size,
      baseline_start_date: event.baseline_start_date,
      baseline_end_date: event.baseline_end_date,
      current_start_date: event.current_start_date,
      current_end_date: event.current_end_date,
      onset_date: event.onset_date,
      detected_at: event.detected_at,
      last_observed_at: event.last_observed_at,
      resolved_at: event.resolved_at,
      supporting_pitches: event.supporting_pitches,
      metadata: event.metadata
    }
  end
end
