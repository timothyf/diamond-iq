class CreateSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :schedules do |t|
      t.integer :season, null: false
      t.string :schedule_type, null: false, default: "regular"
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.string :source_name, null: false
      t.string :source_key, null: false
      t.string :source_url
      t.datetime :last_synced_at, null: false
      t.jsonb :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :schedules, :source_key, unique: true
    add_index :schedules, [:season, :schedule_type]
    add_check_constraint :schedules, "end_date >= start_date", name: "schedules_valid_date_range"
  end
end
