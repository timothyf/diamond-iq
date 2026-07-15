class DefineRosterSnapshotsAndMembershipSources < ActiveRecord::Migration[7.1]
  def up
    add_column :rosters, :roster_type, :string, null: false, default: "40Man"
    add_column :rosters, :snapshot_on, :date
    add_column :rosters, :source_name, :string, null: false, default: "derived_team_memberships"
    add_column :rosters, :last_synced_at, :datetime
    add_column :rosters, :raw_data, :jsonb, null: false, default: {}

    execute <<~SQL.squish
      UPDATE rosters
      SET snapshot_on = COALESCE(snapshot_on, updated_at::date),
          last_synced_at = COALESCE(last_synced_at, updated_at)
    SQL

    change_column_null :rosters, :snapshot_on, false
    change_column_null :rosters, :last_synced_at, false

    add_column :team_memberships, :source_status_code, :string
    add_column :team_memberships, :source_status_description, :string
    add_column :team_memberships, :source_url, :string
    add_column :team_memberships, :raw_data, :jsonb, null: false, default: {}
  end

  def down
    remove_column :team_memberships, :raw_data
    remove_column :team_memberships, :source_url
    remove_column :team_memberships, :source_status_description
    remove_column :team_memberships, :source_status_code

    remove_column :rosters, :raw_data
    remove_column :rosters, :last_synced_at
    remove_column :rosters, :source_name
    remove_column :rosters, :snapshot_on
    remove_column :rosters, :roster_type
  end
end
