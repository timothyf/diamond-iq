class AdminTaskRunSerializer
  def self.call(task_run)
    {
      id: task_run.id,
      task_name: task_run.task_name,
      status: task_run.status,
      task_parameters: task_run.task_parameters,
      total_items: task_run.total_items,
      completed_items: task_run.completed_items,
      failed_items: task_run.failed_items,
      processed_items: task_run.processed_items,
      progress_percentage: task_run.progress_percentage,
      current_item_mlb_id: task_run.current_item_mlb_id,
      current_item_label: task_run.current_item_label,
      cancel_requested: task_run.cancel_requested?,
      error_message: task_run.error_message,
      result_data: task_run.result_data,
      elapsed_seconds: task_run.elapsed_seconds,
      estimated_remaining_seconds: task_run.estimated_remaining_seconds,
      started_at: task_run.started_at,
      finished_at: task_run.finished_at,
      last_heartbeat_at: task_run.last_heartbeat_at,
      created_at: task_run.created_at,
      updated_at: task_run.updated_at
    }
  end
end
