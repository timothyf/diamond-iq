class CreateTeamMemberships < ActiveRecord::Migration[7.1]
  def change
    create_table :team_memberships do |t|
      t.references :player, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on
      t.string :roster_status, null: false
      t.string :primary_position
      t.jsonb :secondary_positions, null: false, default: []
      t.string :jersey_number
      t.string :source_name, null: false
      t.datetime :last_synced_at, null: false

      t.timestamps
    end

    add_index :team_memberships, [:player_id, :team_id, :starts_on], name: "index_team_memberships_on_player_team_start"
    add_index :team_memberships, [:team_id, :starts_on, :ends_on], name: "index_team_memberships_on_team_date_window"
    add_index :team_memberships, :roster_status

    add_check_constraint :team_memberships, "ends_on IS NULL OR ends_on >= starts_on", name: "team_memberships_valid_date_range"
  end
end