class CreateNotesAndTags < ActiveRecord::Migration[7.1]
  def change
    create_table :tags do |t|
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :color, null: false, default: "#20543c"
      t.timestamps
    end
    add_index :tags, "LOWER(name)", unique: true, name: "index_tags_on_lower_name"

    create_table :notes do |t|
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :last_edited_by, null: false, foreign_key: { to_table: :users }
      t.string :target_type, null: false
      t.string :target_key, null: false
      t.text :body, null: false
      t.date :note_date, null: false
      t.jsonb :target_metadata, null: false, default: {}
      t.datetime :archived_at
      t.timestamps
    end
    add_index :notes, [ :target_type, :target_key, :note_date ], name: "index_notes_on_target_and_date"
    add_index :notes, :archived_at

    create_table :note_revisions do |t|
      t.references :note, null: false, foreign_key: true
      t.references :editor, null: false, foreign_key: { to_table: :users }
      t.integer :version, null: false
      t.string :action, null: false, default: "updated"
      t.text :body, null: false
      t.date :note_date, null: false
      t.jsonb :tag_names, null: false, default: []
      t.timestamps
    end
    add_index :note_revisions, [ :note_id, :version ], unique: true

    create_table :note_taggings do |t|
      t.references :note, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :note_taggings, [ :note_id, :tag_id ], unique: true
  end
end
