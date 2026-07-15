class LinkPitchDataToGames < ActiveRecord::Migration[7.1]
  def up
    add_reference :pitch_data, :game, null: true, foreign_key: true, index: true

    execute <<~SQL.squish
      UPDATE pitch_data
      SET game_id = games.id
      FROM games
      WHERE pitch_data.game_pk = games.mlb_id
        AND pitch_data.game_id IS NULL
    SQL
  end

  def down
    remove_reference :pitch_data, :game, foreign_key: true, index: true
  end
end
