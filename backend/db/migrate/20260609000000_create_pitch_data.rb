class CreatePitchData < ActiveRecord::Migration[7.1]
  def change
    create_table :pitch_data do |t|
      t.date :source_start_date
      t.date :source_end_date
      t.datetime :fetched_at_utc
      t.date :game_date
      t.bigint :game_pk, null: false
      t.string :game_type
      t.string :home_team
      t.string :away_team
      t.integer :inning
      t.string :inning_topbot
      t.integer :at_bat_number, null: false
      t.integer :pitch_number, null: false
      t.bigint :pitcher
      t.string :player_name
      t.bigint :batter
      t.string :stand
      t.string :p_throws
      t.string :pitch_type
      t.string :pitch_name
      t.string :description
      t.string :events
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :pitch_data, [:game_pk, :at_bat_number, :pitch_number], unique: true, name: "idx_pitch_data_unique_pitch"
    add_index :pitch_data, :game_date
    add_index :pitch_data, :pitcher
    add_index :pitch_data, :batter
    add_index :pitch_data, :pitch_type
  end
end