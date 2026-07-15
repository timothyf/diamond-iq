class AddAdminCoverageIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :player_season_stats, :season, algorithm: :concurrently, if_not_exists: true
  end
end
