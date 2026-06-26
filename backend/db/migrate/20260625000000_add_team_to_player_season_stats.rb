class AddTeamToPlayerSeasonStats < ActiveRecord::Migration[7.1]
  def change
    add_reference :player_season_stats, :team, foreign_key: true
  end
end