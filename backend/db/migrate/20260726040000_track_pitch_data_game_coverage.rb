class TrackPitchDataGameCoverage < ActiveRecord::Migration[7.1]
  def up
    add_column :games, :pitch_data_complete_at, :datetime
    add_column :games, :pitch_data_row_count, :integer, null: false, default: 0
    add_index :games, :pitch_data_complete_at

    execute <<~SQL.squish
      UPDATE games
      SET pitch_data_complete_at = CURRENT_TIMESTAMP,
          pitch_data_row_count = coverage.row_count
      FROM (
        SELECT game_id, COUNT(*) AS row_count
        FROM pitch_data
        WHERE game_id IS NOT NULL
        GROUP BY game_id
      ) AS coverage
      WHERE games.id = coverage.game_id
    SQL
  end

  def down
    remove_index :games, :pitch_data_complete_at
    remove_column :games, :pitch_data_row_count
    remove_column :games, :pitch_data_complete_at
  end
end
