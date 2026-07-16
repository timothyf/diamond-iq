class CreateAdminTaskRuns < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_task_runs do |t|
      t.string :task_name, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :task_parameters, null: false, default: {}
      t.jsonb :result_data, null: false, default: {}
      t.text :error_message
      t.integer :total_items, null: false, default: 0
      t.integer :completed_items, null: false, default: 0
      t.integer :failed_items, null: false, default: 0
      t.bigint :current_item_mlb_id
      t.string :current_item_label
      t.datetime :cancel_requested_at
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :last_heartbeat_at

      t.timestamps
    end

    add_index :admin_task_runs, [ :task_name, :status, :created_at ], name: "idx_admin_task_runs_active_lookup"
    add_index :admin_task_runs, :created_at
  end
end
