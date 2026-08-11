class PlayerTrendEventDetector
  Result = Data.define(:candidates, :evaluated_identities)

  CALCULATION_VERSION = "1.0.0"
  PITCH_WINDOW = 100
  PLATE_APPEARANCE_WINDOW = 50
  MIN_VELOCITY_SAMPLES = 20
  MIN_CHASE_OPPORTUNITIES = 25
  MAX_SUPPORTING_PITCHES = 12
  SWING_DESCRIPTIONS = DailyAnalyticsCalculator::SWING_DESCRIPTIONS
  PITCH_COLUMNS = %i[
    id game_date game_pk at_bat_number pitch_number pitch_type pitch_name description
    zone release_speed
  ].freeze

  THRESHOLDS = {
    velocity_loss: { warning: 1.0, critical: 2.0, unit: "mph" },
    pitch_mix_change: { warning: 10.0, critical: 20.0, unit: "percentage_points" },
    chase_rate_movement: { warning: 8.0, critical: 15.0, unit: "percentage_points" }
  }.freeze

  def initialize(player:, as_of: nil)
    @player = player
    @as_of = as_of || latest_pitch_date
  end

  def result
    return Result.new([], []) if as_of.blank?

    candidates = []
    evaluated = []
    detect_pitching(candidates, evaluated)
    detect_batting(candidates, evaluated)
    Result.new(candidates, evaluated.uniq)
  end

  private

  attr_reader :player, :as_of

  def detect_pitching(candidates, evaluated)
    rows = recent_rows(:pitcher, PITCH_WINDOW * 2)
    return if rows.length < PITCH_WINDOW * 2

    baseline, current = rows.each_slice(PITCH_WINDOW).to_a
    detect_velocity(baseline, current, candidates, evaluated)
    detect_pitch_mix(baseline, current, candidates, evaluated)
    detect_chase("pitcher", baseline, current, candidates, evaluated)
  end

  def detect_batting(candidates, evaluated)
    rows = recent_rows(:batter, 1_200)
    appearances = rows.group_by { |pitch| [ pitch.game_pk, pitch.at_bat_number ] }.values
      .sort_by { |group| pitch_order(group.first) }
      .last(PLATE_APPEARANCE_WINDOW * 2)
    return if appearances.length < PLATE_APPEARANCE_WINDOW * 2

    baseline_appearances, current_appearances = appearances.each_slice(PLATE_APPEARANCE_WINDOW).to_a
    detect_chase("batter", baseline_appearances.flatten, current_appearances.flatten, candidates, evaluated)
  end

  def detect_velocity(baseline, current, candidates, evaluated)
    pitch_types = (baseline.map(&:pitch_type) & current.map(&:pitch_type)).compact.uniq
    pitch_types.each do |pitch_type|
      baseline_rows = baseline.select { |pitch| pitch.pitch_type == pitch_type && pitch.release_speed.present? }
      current_rows = current.select { |pitch| pitch.pitch_type == pitch_type && pitch.release_speed.present? }
      next if baseline_rows.length < MIN_VELOCITY_SAMPLES || current_rows.length < MIN_VELOCITY_SAMPLES

      identity = identity_for("velocity_loss", "pitcher", "average_velocity", pitch_type)
      evaluated << identity
      baseline_value = average(baseline_rows.map(&:release_speed))
      current_value = average(current_rows.map(&:release_speed))
      change = rounded(current_value - baseline_value)
      magnitude = -change
      severity = severity_for(:velocity_loss, magnitude)
      next unless severity

      candidates << candidate(
        identity: identity,
        event_type: "velocity_loss",
        role: "pitcher",
        metric_key: "average_velocity",
        pitch_type: pitch_type,
        direction: "decrease",
        severity: severity,
        baseline_value: baseline_value,
        current_value: current_value,
        change_value: change,
        baseline_rows: baseline_rows,
        current_rows: current_rows,
        sample_size: current_rows.length,
        baseline_sample_size: baseline_rows.length,
        supporting_rows: current_rows.sort_by { |pitch| pitch.release_speed.to_f }.first(MAX_SUPPORTING_PITCHES),
        threshold_type: :velocity_loss
      )
    end
  end

  def detect_pitch_mix(baseline, current, candidates, evaluated)
    (baseline.map(&:pitch_type) | current.map(&:pitch_type)).compact.uniq.each do |pitch_type|
      identity = identity_for("pitch_mix_change", "pitcher", "usage_percentage", pitch_type)
      evaluated << identity
      baseline_value = percentage(baseline.count { |pitch| pitch.pitch_type == pitch_type }, baseline.length)
      current_value = percentage(current.count { |pitch| pitch.pitch_type == pitch_type }, current.length)
      change = rounded(current_value - baseline_value)
      severity = severity_for(:pitch_mix_change, change.abs)
      next unless severity

      supporting = if change.positive?
        current.select { |pitch| pitch.pitch_type == pitch_type }.last(MAX_SUPPORTING_PITCHES)
      else
        current.last(MAX_SUPPORTING_PITCHES)
      end
      candidates << candidate(
        identity: identity,
        event_type: "pitch_mix_change",
        role: "pitcher",
        metric_key: "usage_percentage",
        pitch_type: pitch_type,
        direction: direction(change),
        severity: severity,
        baseline_value: baseline_value,
        current_value: current_value,
        change_value: change,
        baseline_rows: baseline,
        current_rows: current,
        sample_size: current.length,
        baseline_sample_size: baseline.length,
        supporting_rows: supporting,
        threshold_type: :pitch_mix_change
      )
    end
  end

  def detect_chase(role, baseline, current, candidates, evaluated)
    baseline_opportunities = baseline.select { |pitch| chase_opportunity?(pitch) }
    current_opportunities = current.select { |pitch| chase_opportunity?(pitch) }
    return if baseline_opportunities.length < MIN_CHASE_OPPORTUNITIES ||
      current_opportunities.length < MIN_CHASE_OPPORTUNITIES

    identity = identity_for("chase_rate_movement", role, "chase_percentage", nil)
    evaluated << identity
    baseline_value = percentage(baseline_opportunities.count { |pitch| swing?(pitch) }, baseline_opportunities.length)
    current_value = percentage(current_opportunities.count { |pitch| swing?(pitch) }, current_opportunities.length)
    change = rounded(current_value - baseline_value)
    severity = severity_for(:chase_rate_movement, change.abs)
    return unless severity

    changed_rows = current_opportunities.select { |pitch| swing?(pitch) == change.positive? }
    candidates << candidate(
      identity: identity,
      event_type: "chase_rate_movement",
      role: role,
      metric_key: "chase_percentage",
      pitch_type: nil,
      direction: direction(change),
      severity: severity,
      baseline_value: baseline_value,
      current_value: current_value,
      change_value: change,
      baseline_rows: baseline_opportunities,
      current_rows: current_opportunities,
      sample_size: current_opportunities.length,
      baseline_sample_size: baseline_opportunities.length,
      supporting_rows: changed_rows.last(MAX_SUPPORTING_PITCHES),
      threshold_type: :chase_rate_movement
    )
  end

  def candidate(identity:, threshold_type:, baseline_rows:, current_rows:, supporting_rows:, **attributes)
    thresholds = THRESHOLDS.fetch(threshold_type)
    attributes.merge(
      identity_key: identity,
      unit: thresholds.fetch(:unit),
      threshold_value: thresholds.fetch(attributes.fetch(:severity).to_sym),
      thresholds: thresholds.except(:unit).stringify_keys,
      baseline_start_date: baseline_rows.first.game_date,
      baseline_end_date: baseline_rows.last.game_date,
      current_start_date: current_rows.first.game_date,
      current_end_date: current_rows.last.game_date,
      onset_date: current_rows.first.game_date,
      calculation_version: CALCULATION_VERSION,
      supporting_pitches: supporting_rows.map { |pitch| serialize_pitch(pitch) },
      metadata: {
        "window_type" => attributes.fetch(:role) == "batter" ? "plate_appearances" : "pitches",
        "window_size" => attributes.fetch(:role) == "batter" ? PLATE_APPEARANCE_WINDOW : PITCH_WINDOW
      }
    )
  end

  def recent_rows(role, limit)
    PitchDatum.where(role => player.mlb_id).where("game_date <= ?", as_of)
      .where.not(game_date: nil)
      .select(*PITCH_COLUMNS)
      .order(game_date: :desc, game_pk: :desc, at_bat_number: :desc, pitch_number: :desc)
      .limit(limit)
      .to_a
      .reverse
  end

  def latest_pitch_date
    [
      PitchDatum.where(pitcher: player.mlb_id).maximum(:game_date),
      PitchDatum.where(batter: player.mlb_id).maximum(:game_date)
    ].compact.max
  end

  def identity_for(event_type, role, metric_key, pitch_type)
    [ event_type, role, metric_key, pitch_type.presence || "all" ].join(":")
  end

  def severity_for(type, magnitude)
    thresholds = THRESHOLDS.fetch(type)
    return "critical" if magnitude >= thresholds.fetch(:critical)
    return "warning" if magnitude >= thresholds.fetch(:warning)
    nil
  end

  def serialize_pitch(pitch)
    {
      "pitch_data_id" => pitch.id,
      "game_pk" => pitch.game_pk,
      "game_date" => pitch.game_date.iso8601,
      "at_bat_number" => pitch.at_bat_number,
      "pitch_number" => pitch.pitch_number,
      "pitch_type" => pitch.pitch_type,
      "pitch_name" => pitch.pitch_name,
      "description" => pitch.description,
      "zone" => pitch.zone,
      "release_speed" => pitch.release_speed
    }
  end

  def pitch_order(pitch)
    [ pitch.game_date, pitch.game_pk, pitch.at_bat_number, pitch.pitch_number ]
  end

  def chase_opportunity?(pitch)
    pitch.zone.present? && !pitch.zone.to_i.between?(1, 9)
  end

  def swing?(pitch)
    DailyAnalyticsCalculator.swing?(pitch)
  end

  def average(values)
    rounded(values.sum(&:to_f) / values.length)
  end

  def percentage(numerator, denominator)
    rounded(numerator.to_f / denominator * 100)
  end

  def rounded(value)
    value.round(4)
  end

  def direction(change)
    change.positive? ? "increase" : "decrease"
  end
end
