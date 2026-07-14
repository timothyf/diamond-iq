class UpdatePlayerSeasonStatsUniquenessForTeamSplits < ActiveRecord::Migration[7.1]
  OLD_UNIQUE_INDEX_NAME = "idx_on_player_id_stat_type_id_season_58662b691e".freeze
  TEAM_SPLIT_INDEX_NAME = "idx_player_season_stats_unique_team_split".freeze
  TOT_INDEX_NAME = "idx_player_season_stats_unique_tot".freeze

  def change
    remove_index :player_season_stats, name: OLD_UNIQUE_INDEX_NAME

    add_index :player_season_stats,
      [:player_id, :stat_type_id, :season, :team_id],
      unique: true,
      where: "team_id IS NOT NULL",
      name: TEAM_SPLIT_INDEX_NAME

    add_index :player_season_stats,
      [:player_id, :stat_type_id, :season],
      unique: true,
      where: "team_id IS NULL",
      name: TOT_INDEX_NAME
  end
end