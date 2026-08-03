class AddHomeSnapshotIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :games, :last_synced_at,
      name: "idx_games_last_synced_at",
      algorithm: :concurrently,
      if_not_exists: true
    add_index :games, :details_last_synced_at,
      name: "idx_games_details_last_synced_at",
      algorithm: :concurrently,
      if_not_exists: true
    add_index :player_season_stats, :updated_at,
      name: "idx_player_season_stats_updated_at",
      algorithm: :concurrently,
      if_not_exists: true
    add_index :team_daily_metrics, :calculated_at,
      name: "idx_team_daily_metrics_calculated_at",
      algorithm: :concurrently,
      if_not_exists: true
    add_index :player_season_stats,
      [ :season, :stat_type_id, :value ],
      order: { value: :desc },
      include: [ :player_id, :team_id, :scope_type, :scope_key ],
      name: "idx_player_season_stats_home_leaderboard",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
