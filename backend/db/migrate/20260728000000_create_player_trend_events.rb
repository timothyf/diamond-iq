class CreatePlayerTrendEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :player_trend_events do |t|
      t.references :player, null: false, foreign_key: true
      t.string :identity_key, null: false
      t.string :event_type, null: false
      t.string :role, null: false
      t.string :metric_key, null: false
      t.string :pitch_type
      t.string :direction, null: false
      t.string :severity, null: false
      t.string :status, null: false, default: "active"
      t.string :unit, null: false
      t.decimal :baseline_value, precision: 12, scale: 4, null: false
      t.decimal :current_value, precision: 12, scale: 4, null: false
      t.decimal :change_value, precision: 12, scale: 4, null: false
      t.decimal :threshold_value, precision: 12, scale: 4, null: false
      t.integer :baseline_sample_size, null: false
      t.integer :sample_size, null: false
      t.date :baseline_start_date, null: false
      t.date :baseline_end_date, null: false
      t.date :current_start_date, null: false
      t.date :current_end_date, null: false
      t.date :onset_date, null: false
      t.datetime :detected_at, null: false
      t.datetime :last_observed_at, null: false
      t.datetime :resolved_at
      t.string :calculation_version, null: false
      t.jsonb :thresholds, null: false, default: {}
      t.jsonb :supporting_pitches, null: false, default: []
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :player_trend_events, [ :player_id, :status, :severity, :onset_date ],
      name: "idx_player_trend_events_feed"
    add_index :player_trend_events, [ :player_id, :identity_key ],
      unique: true,
      where: "status = 'active'",
      name: "idx_player_trend_events_one_active"

    add_check_constraint :player_trend_events,
      "status IN ('active', 'resolved')",
      name: "player_trend_events_status"
    add_check_constraint :player_trend_events,
      "severity IN ('warning', 'critical')",
      name: "player_trend_events_severity"
    add_check_constraint :player_trend_events,
      "direction IN ('increase', 'decrease')",
      name: "player_trend_events_direction"
    add_check_constraint :player_trend_events,
      "role IN ('batter', 'pitcher')",
      name: "player_trend_events_role"
    add_check_constraint :player_trend_events,
      "sample_size > 0 AND baseline_sample_size > 0",
      name: "player_trend_events_sample_sizes"
  end
end
