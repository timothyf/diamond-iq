class CreateContextualBenchmarks < ActiveRecord::Migration[7.1]
  def change
    create_table :league_metric_benchmarks do |t|
      t.string :metric_key, null: false
      t.string :metric_group, null: false
      t.string :display_name, null: false
      t.string :peer_group_type, null: false
      t.string :peer_group_key, null: false
      t.string :dimension_type, null: false, default: ""
      t.string :dimension_value, null: false, default: ""
      t.string :directionality, null: false
      t.decimal :average_value, precision: 14, scale: 6, null: false
      t.bigint :sample_size, null: false, default: 0
      t.integer :player_count, null: false, default: 0
      t.date :source_start_date, null: false
      t.date :source_end_date, null: false
      t.string :calculation_version, null: false
      t.datetime :calculated_at, null: false
      t.string :source_name, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :league_metric_benchmarks,
      [ :metric_key, :peer_group_type, :peer_group_key, :dimension_type, :dimension_value,
        :source_start_date, :source_end_date, :calculation_version ],
      unique: true,
      name: "idx_league_metric_benchmarks_identity"
    add_index :league_metric_benchmarks,
      [ :source_end_date, :calculation_version ],
      name: "idx_league_metric_benchmarks_latest"
    add_check_constraint :league_metric_benchmarks, "sample_size >= 0", name: "league_benchmarks_sample_nonnegative"
    add_check_constraint :league_metric_benchmarks, "player_count >= 0", name: "league_benchmarks_players_nonnegative"
    add_check_constraint :league_metric_benchmarks, "source_end_date >= source_start_date", name: "league_benchmarks_range_valid"

    create_table :player_metric_percentiles do |t|
      t.references :player, null: false, foreign_key: true
      t.references :league_metric_benchmark, null: false, foreign_key: true
      t.decimal :raw_value, precision: 14, scale: 6, null: false
      t.decimal :percentile, precision: 6, scale: 2, null: false
      t.decimal :previous_value, precision: 14, scale: 6
      t.decimal :change_value, precision: 14, scale: 6
      t.decimal :change_percentage, precision: 12, scale: 4
      t.bigint :sample_size, null: false, default: 0
      t.integer :peer_player_count, null: false, default: 0
      t.date :source_start_date, null: false
      t.date :source_end_date, null: false
      t.date :previous_start_date
      t.date :previous_end_date
      t.string :calculation_version, null: false
      t.datetime :calculated_at, null: false
      t.string :source_name, null: false
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :player_metric_percentiles,
      [ :player_id, :league_metric_benchmark_id ],
      unique: true,
      name: "idx_player_metric_percentiles_identity"
    add_index :player_metric_percentiles,
      [ :player_id, :source_end_date, :calculation_version ],
      name: "idx_player_metric_percentiles_latest"
    add_check_constraint :player_metric_percentiles, "sample_size >= 0", name: "player_percentiles_sample_nonnegative"
    add_check_constraint :player_metric_percentiles, "peer_player_count >= 0", name: "player_percentiles_peers_nonnegative"
    add_check_constraint :player_metric_percentiles, "percentile >= 0 AND percentile <= 100", name: "player_percentiles_value_valid"
    add_check_constraint :player_metric_percentiles, "source_end_date >= source_start_date", name: "player_percentiles_range_valid"
  end
end
