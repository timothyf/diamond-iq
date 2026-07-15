class CreateRosterSnapshots < ActiveRecord::Migration[7.1]
  def change
    create_table :roster_snapshots do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :season, null: false
      t.string :roster_type, null: false
      t.date :snapshot_on, null: false
      t.string :source_name, null: false, default: "MLB Stats API"
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :roster_snapshots,
      [ :team_id, :snapshot_on, :roster_type ],
      unique: true,
      name: "index_roster_snapshots_on_team_date_and_type"
    add_index :roster_snapshots, [ :snapshot_on, :roster_type ]

    create_table :roster_snapshot_players do |t|
      t.references :roster_snapshot, null: false, foreign_key: true
      t.references :player, null: true, foreign_key: true
      t.integer :mlb_id, null: false
      t.string :full_name, null: false
      t.string :first_name
      t.string :last_name
      t.string :jersey_number
      t.string :position_code
      t.string :position_name
      t.string :status_code
      t.string :status_description
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :roster_snapshot_players,
      [ :roster_snapshot_id, :mlb_id ],
      unique: true,
      name: "index_roster_snapshot_players_on_snapshot_and_mlb_id"
    add_index :roster_snapshot_players, :mlb_id
  end
end
