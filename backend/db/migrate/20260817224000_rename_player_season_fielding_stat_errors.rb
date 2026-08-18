class RenamePlayerSeasonFieldingStatErrors < ActiveRecord::Migration[7.1]
  def change
    rename_column :player_season_fielding_stats, :errors, :fielding_errors
  end
end
