class UpdateRostersForPlayerMemberships < ActiveRecord::Migration[7.1]
  def change
    remove_index :rosters, column: [:player_id, :team_id, :season]
    remove_reference :rosters, :player, foreign_key: true

    add_index :rosters, [:team_id, :season], unique: true
  end
end