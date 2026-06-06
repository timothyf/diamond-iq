class CreatePlayerSeasonStats < ActiveRecord::Migration[7.1]
  def change
    create_table :player_season_stats do |t|
      t.references :player, null: false, foreign_key: true
      t.references :stat_type, null: false, foreign_key: true
      t.integer :season, null: false
      t.decimal :value, precision: 12, scale: 4, null: false

      t.timestamps
    end

    add_index :player_season_stats, [:player_id, :stat_type_id, :season], unique: true
  end
end
