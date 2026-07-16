class AddPlayerTrendPitchIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :pitch_data, [ :batter, :game_date ], name: "idx_pitch_data_batter_game_date"
    add_index :pitch_data, [ :pitcher, :game_date ], name: "idx_pitch_data_pitcher_game_date"
  end
end
