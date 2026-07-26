class CreateWatchlistsAndAcquisitionEvaluations < ActiveRecord::Migration[7.1]
  def change
    create_table :watchlists do |t|
      t.string :name, null: false
      t.text :description
      t.timestamps
    end

    create_table :watchlist_entries do |t|
      t.references :watchlist, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.string :priority, null: false, default: "medium"
      t.string :status, null: false, default: "scouting"
      t.string :recommendation, null: false, default: "monitor"
      t.integer :fit_score
      t.integer :need_score
      t.integer :cost_score
      t.integer :risk_score
      t.string :tags, array: true, null: false, default: []
      t.text :notes
      t.timestamps
    end

    add_index :watchlists, :name, unique: true
    add_index :watchlist_entries, [ :watchlist_id, :player_id ], unique: true
    add_check_constraint :watchlist_entries, "priority IN ('low', 'medium', 'high')", name: "watchlist_entries_valid_priority"
    add_check_constraint :watchlist_entries, "status IN ('scouting', 'active', 'paused', 'closed')", name: "watchlist_entries_valid_status"
    add_check_constraint :watchlist_entries, "recommendation IN ('pursue', 'monitor', 'pass')", name: "watchlist_entries_valid_recommendation"
    %i[fit_score need_score cost_score risk_score].each do |column|
      add_check_constraint :watchlist_entries, "#{column} IS NULL OR #{column} BETWEEN 1 AND 5", name: "watchlist_entries_#{column}_range"
    end
  end
end
