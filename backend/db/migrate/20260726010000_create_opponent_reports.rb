class CreateOpponentReports < ActiveRecord::Migration[7.1]
  def change
    create_table :opponent_reports do |t|
      t.references :team, null: false, foreign_key: true
      t.references :opponent_team, null: false, foreign_key: { to_table: :teams }
      t.integer :season, null: false
      t.date :series_starts_on, null: false
      t.date :series_ends_on, null: false
      t.string :title, null: false
      t.jsonb :snapshot, null: false, default: {}
      t.datetime :generated_at, null: false

      t.timestamps
    end

    add_index :opponent_reports, [ :team_id, :generated_at ]
    add_index :opponent_reports, [ :team_id, :opponent_team_id, :series_starts_on ],
      name: "index_opponent_reports_on_series"
    add_check_constraint :opponent_reports, "series_ends_on >= series_starts_on",
      name: "opponent_reports_valid_series_range"
  end
end
