class AddInitiatedByToAdminTaskRuns < ActiveRecord::Migration[7.1]
  def change
    add_reference :admin_task_runs, :initiated_by, foreign_key: { to_table: :users }, null: true
  end
end
