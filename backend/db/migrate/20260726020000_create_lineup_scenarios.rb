class CreateLineupScenarios < ActiveRecord::Migration[7.1]
  def change
    create_table :lineup_scenarios do |t|
      t.references :team, null: false, foreign_key: true
      t.integer :season, null: false
      t.date :scenario_date, null: false
      t.string :name, null: false
      t.text :notes
      t.datetime :validated_at

      t.timestamps
    end

    create_table :lineup_scenario_entries do |t|
      t.references :lineup_scenario, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :batting_slot, null: false
      t.string :defensive_position, null: false

      t.timestamps
    end

    add_index :lineup_scenarios, [ :team_id, :season, :scenario_date ], name: "index_lineup_scenarios_on_team_season_date"
    add_index :lineup_scenario_entries, [ :lineup_scenario_id, :batting_slot ], unique: true, name: "index_lineup_scenario_entries_on_slot"
    add_index :lineup_scenario_entries, [ :lineup_scenario_id, :player_id ], unique: true, name: "index_lineup_scenario_entries_on_player"
    add_check_constraint :lineup_scenario_entries, "batting_slot BETWEEN 1 AND 9", name: "lineup_scenario_entries_valid_slot"
  end
end
