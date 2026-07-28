class CreateAcquisitionNeedProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :need_profiles do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :criteria, null: false, default: {}
      t.jsonb :weights, null: false, default: {}
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_index :need_profiles, [ :team_id, :name ], unique: true

    add_reference :watchlists, :need_profile, foreign_key: true
    add_column :watchlist_entries, :calculated_fit_score, :decimal, precision: 5, scale: 2
    add_column :watchlist_entries, :fit_breakdown, :jsonb, null: false, default: {}
    add_column :watchlist_entries, :fit_calculated_at, :datetime
    add_index :watchlist_entries, :calculated_fit_score
    add_check_constraint :watchlist_entries,
      "calculated_fit_score IS NULL OR calculated_fit_score BETWEEN 0 AND 100",
      name: "watchlist_entries_calculated_fit_range"
  end
end
