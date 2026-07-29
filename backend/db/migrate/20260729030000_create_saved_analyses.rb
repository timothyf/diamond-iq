class CreateSavedAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :saved_analyses do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :analysis_type, null: false
      t.string :visibility, null: false, default: "private"
      t.string :reproducible_url, null: false
      t.jsonb :state, null: false, default: {}

      t.timestamps
    end

    add_index :saved_analyses, [ :owner_id, :analysis_type, :name ],
      unique: true, name: "idx_saved_analyses_owner_type_name"
    add_index :saved_analyses, [ :analysis_type, :visibility, :updated_at ],
      name: "idx_saved_analyses_discovery"
  end
end
