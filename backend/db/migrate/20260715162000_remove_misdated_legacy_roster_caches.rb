class RemoveMisdatedLegacyRosterCaches < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL.squish
      DELETE FROM roster_players
      WHERE roster_id IN (
        SELECT id
        FROM rosters
        WHERE snapshot_on > make_date(season, 12, 31)
      )
    SQL

    execute <<~SQL.squish
      DELETE FROM rosters
      WHERE snapshot_on > make_date(season, 12, 31)
    SQL
  end

  def down
    # These rows were compatibility caches with invalid observation dates and
    # can be recreated from a correctly dated synchronization.
  end
end
