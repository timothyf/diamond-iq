class AddScopeFieldsToPlayerSeasonStats < ActiveRecord::Migration[7.1]
  NEW_UNIQUE_INDEX_NAME = "idx_player_season_stats_unique_scope".freeze
  TEAM_SPLIT_INDEX_NAME = "idx_player_season_stats_unique_team_split".freeze
  TOT_INDEX_NAME = "idx_player_season_stats_unique_tot".freeze

  def up
    add_column :player_season_stats, :scope_type, :string
    add_column :player_season_stats, :scope_key, :string

    execute <<~SQL.squish
      UPDATE player_season_stats
      SET scope_type = CASE
        WHEN teams.abbreviation = 'TOT' OR teams.mlb_id = 0 THEN 'combined'
        ELSE 'team'
      END,
      scope_key = CASE
        WHEN teams.abbreviation = 'TOT' OR teams.mlb_id = 0 THEN 'TOT'
        ELSE COALESCE(NULLIF(teams.abbreviation, ''), teams.mlb_id::text, player_season_stats.team_id::text)
      END
      FROM teams
      WHERE player_season_stats.team_id = teams.id
        AND (player_season_stats.scope_type IS NULL OR player_season_stats.scope_key IS NULL)
    SQL

    execute <<~SQL.squish
      UPDATE player_season_stats
      SET scope_type = COALESCE(scope_type, 'combined'),
          scope_key = COALESCE(scope_key, 'TOT')
      WHERE scope_type IS NULL OR scope_key IS NULL
    SQL

    remove_index :player_season_stats, name: TEAM_SPLIT_INDEX_NAME
    remove_index :player_season_stats, name: TOT_INDEX_NAME

    add_index :player_season_stats,
      [:player_id, :stat_type_id, :season, :scope_type, :scope_key],
      unique: true,
      name: NEW_UNIQUE_INDEX_NAME

    add_check_constraint :player_season_stats,
      "scope_type IN ('team', 'combined', 'league')",
      name: "player_season_stats_valid_scope_type"
  end

  def down
    remove_check_constraint :player_season_stats, name: "player_season_stats_valid_scope_type"

    remove_index :player_season_stats, name: NEW_UNIQUE_INDEX_NAME

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

    remove_column :player_season_stats, :scope_key
    remove_column :player_season_stats, :scope_type
  end
end