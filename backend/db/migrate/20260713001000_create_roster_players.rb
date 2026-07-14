class CreateRosterPlayers < ActiveRecord::Migration[7.1]
  def change
    create_table :roster_players do |t|
      t.references :roster, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true

      t.timestamps
    end

    add_index :roster_players, [:roster_id, :player_id], unique: true
  end
end