class AddRemainingTimeAnchorsToAdminTaskRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :admin_task_runs, :estimated_duration_seconds, :integer
    add_column :admin_task_runs, :remaining_time_anchor_at, :datetime
  end
end
