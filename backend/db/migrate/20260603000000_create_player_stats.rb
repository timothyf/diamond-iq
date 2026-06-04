class CreatePlayerStats < ActiveRecord::Migration[7.1]
  def change
    create_table :player_stats do |t|
      t.string :player_id, null: false
      t.string :source_url, null: false
      t.integer :row_number, null: false
      t.jsonb :stats_data, null: false, default: {}

      t.timestamps
    end

    add_index :player_stats, [:player_id, :source_url]
    add_index :player_stats, [:player_id, :source_url, :row_number], unique: true
  end
end
