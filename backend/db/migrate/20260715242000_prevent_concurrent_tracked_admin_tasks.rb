class PreventConcurrentTrackedAdminTasks < ActiveRecord::Migration[7.1]
  def change
    add_index :admin_task_runs,
      :task_name,
      unique: true,
      where: "status IN ('queued', 'running')",
      name: "idx_admin_task_runs_one_active_per_task"
  end
end
