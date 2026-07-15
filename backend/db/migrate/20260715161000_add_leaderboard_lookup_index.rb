class AddLeaderboardLookupIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEX_NAME = "idx_player_season_stats_leaderboard_lookup".freeze

  def change
    add_index :player_season_stats,
      [ :stat_type_id, :value ],
      order: { value: :desc },
      include: [ :player_id, :team_id, :season, :scope_type, :scope_key ],
      name: INDEX_NAME,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
