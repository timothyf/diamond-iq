class CreateRosters < ActiveRecord::Migration[7.1]
  def change
    create_table :rosters do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :season, null: false

      t.timestamps
    end

    add_index :rosters, [:team_id, :season], unique: true
  end
end
  end
end