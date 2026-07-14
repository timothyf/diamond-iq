class CreatePlayerProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :player_profiles do |t|
      t.references :player, null: false, foreign_key: true, index: { unique: true }
      t.date :birth_date
      t.integer :height_inches
      t.integer :weight_pounds
      t.string :bats, limit: 1
      t.string :throws, limit: 1
      t.date :mlb_debut_date
      t.string :headshot_id
      t.string :headshot_url_override
      t.string :source_name, null: false
      t.datetime :source_updated_at
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_check_constraint :player_profiles,
                         "height_inches IS NULL OR height_inches > 0",
                         name: "player_profiles_positive_height"
    add_check_constraint :player_profiles,
                         "weight_pounds IS NULL OR weight_pounds > 0",
                         name: "player_profiles_positive_weight"
    add_check_constraint :player_profiles,
                         "bats IS NULL OR bats IN ('L', 'R', 'S')",
                         name: "player_profiles_valid_bats"
    add_check_constraint :player_profiles,
                         "throws IS NULL OR throws IN ('L', 'R')",
                         name: "player_profiles_valid_throws"
  end
end
