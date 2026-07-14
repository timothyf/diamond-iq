class AddOverlapProtectionToTeamMemberships < ActiveRecord::Migration[7.1]
  CONSTRAINT_NAME = "team_memberships_no_overlap_same_status".freeze

  def up
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    execute <<~SQL
      ALTER TABLE team_memberships
      ADD CONSTRAINT #{CONSTRAINT_NAME}
      EXCLUDE USING gist (
        player_id WITH =,
        team_id WITH =,
        lower(roster_status) WITH =,
        daterange(starts_on, COALESCE(ends_on + 1, 'infinity'::date), '[)') WITH &&
      );
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE team_memberships
      DROP CONSTRAINT IF EXISTS #{CONSTRAINT_NAME};
    SQL
  end
end