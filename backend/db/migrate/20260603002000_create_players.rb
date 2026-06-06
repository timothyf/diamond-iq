class CreatePlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :players do |t|
      t.integer :mlb_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.references :team, null: false, foreign_key: true

      t.timestamps
    end

    add_index :players, :mlb_id, unique: true
  end
end
