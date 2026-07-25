class CreatePlayerIdMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :player_id_mappings do |t|
      t.integer :mlb_id, null: false
      t.string :chadwick_id, null: false
      t.uuid :chadwick_uuid, null: false
      t.string :retrosheet_id
      t.string :baseball_reference_id
      t.string :baseball_reference_minors_id
      t.string :fangraphs_id
      t.string :npb_id
      t.string :pro_football_reference_id
      t.string :basketball_reference_id
      t.string :hockey_reference_id
      t.string :wikidata_id
      t.string :source_name, null: false, default: "Chadwick Register"
      t.datetime :imported_at, null: false

      t.timestamps
    end

    add_index :player_id_mappings, :mlb_id, unique: true
    add_index :player_id_mappings, :chadwick_id, unique: true
    add_index :player_id_mappings, :baseball_reference_id
    add_index :player_id_mappings, :fangraphs_id
  end
end
