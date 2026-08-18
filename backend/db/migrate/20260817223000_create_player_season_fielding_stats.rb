class CreatePlayerSeasonFieldingStats < ActiveRecord::Migration[7.1]
  def change
    create_table :player_season_fielding_stats do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, null: true, foreign_key: true
      t.integer :season, null: false
      t.string :team_abbreviation, null: false
      t.string :position, null: false
      t.integer :games
      t.decimal :innings, precision: 7, scale: 1
      t.integer :putouts
      t.integer :assists
      t.integer :errors
      t.decimal :fielding_percentage, precision: 7, scale: 6
      t.decimal :defensive_runs_saved, precision: 7, scale: 2
      t.decimal :outs_above_average, precision: 7, scale: 2
      t.string :source_name, null: false
      t.datetime :last_synced_at, null: false

      t.timestamps
    end

    add_index :player_season_fielding_stats,
      [ :player_id, :season, :team_abbreviation, :position ],
      unique: true,
      name: :idx_player_season_fielding_stats_unique_scope
  end
end
