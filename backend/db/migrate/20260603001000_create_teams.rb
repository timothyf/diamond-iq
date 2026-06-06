class CreateTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.integer :mlb_id, null: false
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.string :team_name, null: false
      t.string :location_name, null: false
      t.string :short_name, null: false
      t.string :team_code, null: false
      t.string :file_code, null: false

      t.timestamps
    end

    add_index :teams, :mlb_id, unique: true
  end
end
