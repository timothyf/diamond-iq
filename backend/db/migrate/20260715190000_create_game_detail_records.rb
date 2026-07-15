class CreateGameDetailRecords < ActiveRecord::Migration[7.1]
  def change
    change_table :games, bulk: true do |t|
      t.string :details_source_url
      t.datetime :details_last_synced_at
      t.jsonb :boxscore_raw_data, null: false, default: {}
      t.jsonb :live_feed_raw_data, null: false, default: {}
    end

    create_table :game_player_batting_lines do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :opponent_team, null: false, foreign_key: { to_table: :teams }
      t.boolean :home, null: false
      t.boolean :starter, null: false, default: false
      t.integer :batting_order
      t.string :position
      t.integer :plate_appearances
      t.integer :at_bats
      t.integer :runs
      t.integer :hits
      t.integer :doubles
      t.integer :triples
      t.integer :home_runs
      t.integer :runs_batted_in
      t.integer :walks
      t.integer :strikeouts
      t.integer :stolen_bases
      t.integer :caught_stealing
      t.decimal :batting_average, precision: 6, scale: 4
      t.decimal :on_base_percentage, precision: 6, scale: 4
      t.decimal :slugging_percentage, precision: 6, scale: 4
      t.decimal :ops, precision: 6, scale: 4
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :game_player_batting_lines, [ :game_id, :player_id ], unique: true, name: "idx_game_batting_lines_game_player"
    add_index :game_player_batting_lines, [ :player_id, :game_id ], name: "idx_game_batting_lines_player_game"

    create_table :game_player_pitching_lines do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :opponent_team, null: false, foreign_key: { to_table: :teams }
      t.boolean :home, null: false
      t.boolean :starter, null: false, default: false
      t.integer :appearance_order
      t.string :innings_pitched
      t.integer :outs_recorded
      t.integer :batters_faced
      t.integer :hits
      t.integer :runs
      t.integer :earned_runs
      t.integer :home_runs
      t.integer :walks
      t.integer :strikeouts
      t.integer :pitches
      t.integer :strikes
      t.decimal :era, precision: 7, scale: 3
      t.decimal :whip, precision: 7, scale: 3
      t.string :decision
      t.integer :holds
      t.integer :saves
      t.integer :blown_saves
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :game_player_pitching_lines, [ :game_id, :player_id ], unique: true, name: "idx_game_pitching_lines_game_player"
    add_index :game_player_pitching_lines, [ :player_id, :game_id ], name: "idx_game_pitching_lines_player_game"

    create_table :plate_appearances do |t|
      t.references :game, null: false, foreign_key: true
      t.references :batter, foreign_key: { to_table: :players }
      t.references :pitcher, foreign_key: { to_table: :players }
      t.references :batting_team, foreign_key: { to_table: :teams }
      t.references :fielding_team, foreign_key: { to_table: :teams }
      t.integer :at_bat_index, null: false
      t.integer :plate_appearance_number, null: false
      t.integer :inning
      t.string :half_inning
      t.string :event
      t.string :event_type
      t.text :description
      t.integer :runs_batted_in
      t.integer :away_score
      t.integer :home_score
      t.integer :outs_after
      t.boolean :complete, null: false, default: false
      t.datetime :started_at
      t.datetime :ended_at
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :plate_appearances, [ :game_id, :at_bat_index ], unique: true
    add_index :plate_appearances, [ :game_id, :plate_appearance_number ], unique: true, name: "idx_plate_appearances_game_number"
    add_index :plate_appearances, [ :batter_id, :game_id ]
    add_index :plate_appearances, [ :pitcher_id, :game_id ]

    create_table :lineup_entries do |t|
      t.references :game, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :batting_order
      t.integer :batting_slot
      t.boolean :starter, null: false, default: false
      t.string :position
      t.jsonb :all_positions, null: false, default: []
      t.jsonb :substitutions, null: false, default: []
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}
      t.timestamps
    end
    add_index :lineup_entries, [ :game_id, :team_id, :player_id ], unique: true, name: "idx_lineup_entries_game_team_player"
    add_index :lineup_entries, [ :game_id, :team_id, :batting_order ], name: "idx_lineup_entries_game_team_order"

    add_reference :pitch_data, :plate_appearance, foreign_key: true
    add_index :pitch_data, [ :plate_appearance_id, :pitch_number ]
  end
end
