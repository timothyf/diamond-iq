class CreateGames < ActiveRecord::Migration[7.1]
  def change
    create_table :games do |t|
      t.references :schedule, null: false, foreign_key: true
      t.bigint :mlb_id, null: false
      t.date :official_date, null: false
      t.datetime :scheduled_at
      t.string :game_type, null: false
      t.string :status, null: false
      t.string :detailed_status
      t.references :home_team, null: false, foreign_key: { to_table: :teams }
      t.references :away_team, null: false, foreign_key: { to_table: :teams }
      t.references :home_probable_pitcher, foreign_key: { to_table: :players }
      t.references :away_probable_pitcher, foreign_key: { to_table: :players }
      t.string :venue_name
      t.integer :game_number
      t.string :doubleheader
      t.integer :home_score
      t.integer :away_score
      t.string :source_name, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :games, :mlb_id, unique: true
    add_index :games, [:official_date, :status]
    add_index :games, [:home_team_id, :official_date]
    add_index :games, [:away_team_id, :official_date]
    add_check_constraint :games, "home_team_id <> away_team_id", name: "games_distinct_teams"
    add_check_constraint :games, "home_score IS NULL OR home_score >= 0", name: "games_nonnegative_home_score"
    add_check_constraint :games, "away_score IS NULL OR away_score >= 0", name: "games_nonnegative_away_score"
  end
end
