require "rails_helper"

RSpec.describe PlayerTrendEventQuery do
  let(:player) { create_player }

  it "serializes persisted event thresholds, samples, onset, and supporting pitches" do
    event = player.trend_events.create!(
      identity_key: "chase_rate_movement:batter:chase_percentage:all",
      event_type: "chase_rate_movement",
      role: "batter",
      metric_key: "chase_percentage",
      direction: "increase",
      severity: "warning",
      status: "active",
      unit: "percentage_points",
      baseline_value: 25,
      current_value: 35,
      change_value: 10,
      threshold_value: 8,
      baseline_sample_size: 30,
      sample_size: 32,
      baseline_start_date: Date.new(2026, 6, 1),
      baseline_end_date: Date.new(2026, 6, 15),
      current_start_date: Date.new(2026, 6, 16),
      current_end_date: Date.new(2026, 6, 30),
      onset_date: Date.new(2026, 6, 16),
      detected_at: Time.current,
      last_observed_at: Time.current,
      calculation_version: "1.0.0",
      thresholds: { warning: 8, critical: 15 },
      supporting_pitches: [ { game_pk: 123, pitch_number: 4 } ],
      metadata: { window_type: "plate_appearances", window_size: 50 }
    )

    result = described_class.new(
      player: player,
      start_date: Date.new(2026, 6, 1),
      end_date: Date.new(2026, 6, 30)
    ).result

    expect(result[:active_count]).to eq(1)
    expect(result[:events]).to contain_exactly(hash_including(
      id: event.id,
      event_type: "chase_rate_movement",
      severity: "warning",
      onset_date: Date.new(2026, 6, 16),
      baseline_sample_size: 30,
      sample_size: 32,
      thresholds: { "warning" => 8, "critical" => 15 },
      supporting_pitches: [ { "game_pk" => 123, "pitch_number" => 4 } ]
    ))
  end
end
