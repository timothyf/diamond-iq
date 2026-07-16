class CreateDailyAnalyticsSummaries < ActiveRecord::Migration[7.1]
  def change
    create_table :player_batting_daily do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      analytics_columns(t)
    end
    add_index :player_batting_daily, [ :player_id, :team_id, :metric_date, :calculation_version ], unique: true, name: "idx_player_batting_daily_identity"

    create_table :player_pitching_daily do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      analytics_columns(t)
    end
    add_index :player_pitching_daily, [ :player_id, :team_id, :metric_date, :calculation_version ], unique: true, name: "idx_player_pitching_daily_identity"

    create_table :pitcher_pitch_type_daily do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :pitch_type, null: false
      t.string :pitch_name
      analytics_columns(t)
    end
    add_index :pitcher_pitch_type_daily, [ :player_id, :metric_date, :pitch_type, :calculation_version ], unique: true, name: "idx_pitcher_pitch_type_daily_identity"

    create_table :batter_split_summaries do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :split_type, null: false
      t.string :split_value, null: false
      analytics_columns(t)
    end
    add_index :batter_split_summaries, [ :player_id, :metric_date, :split_type, :split_value, :calculation_version ], unique: true, name: "idx_batter_split_summaries_identity"

    create_table :pitcher_split_summaries do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, foreign_key: true
      t.string :split_type, null: false
      t.string :split_value, null: false
      analytics_columns(t)
    end
    add_index :pitcher_split_summaries, [ :player_id, :metric_date, :split_type, :split_value, :calculation_version ], unique: true, name: "idx_pitcher_split_summaries_identity"

    create_table :team_daily_metrics do |t|
      t.references :team, null: false, foreign_key: true
      analytics_columns(t)
    end
    add_index :team_daily_metrics, [ :team_id, :metric_date, :calculation_version ], unique: true, name: "idx_team_daily_metrics_identity"
  end

  private

  def analytics_columns(table)
    table.date :metric_date, null: false
    table.date :source_start_date, null: false
    table.date :source_end_date, null: false
    table.integer :sample_size, null: false, default: 0
    table.string :calculation_version, null: false
    table.datetime :calculated_at, null: false
    table.string :source_name, null: false
    table.jsonb :metrics, null: false, default: {}
    table.timestamps

    table.index [ :metric_date, :calculation_version ]
    table.check_constraint "sample_size >= 0", name: "#{table.name}_sample_size_nonnegative"
    table.check_constraint "source_end_date >= source_start_date", name: "#{table.name}_source_range_valid"
  end
end
