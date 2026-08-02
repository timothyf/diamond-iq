class MlbRosterSyncProgressTracker
  def initialize(task_run) = @task_run = task_run

  def start!(total:)
    execution_id = task_run.result_data.to_h["active_execution_job_id"]
    task_run.update!(status: "running", total_items: total, completed_items: 0, failed_items: 0,
      result_data: execution_id ? { "active_execution_job_id" => execution_id } : {}, error_message: nil,
      remaining_time_anchor_at: nil, started_at: task_run.started_at || Time.current,
      finished_at: nil, last_heartbeat_at: Time.current)
  end

  def team_started!(team_mlb_id)
    team = Team.find_by(mlb_id: team_mlb_id)
    task_run.update!(
      current_item_mlb_id: team_mlb_id,
      current_item_label: team ? "#{team.abbreviation} · #{team.name}" : "MLB team #{team_mlb_id}",
      last_heartbeat_at: Time.current
    )
  end

  def team_finished!(success:)
    task_run.reload
    task_run.update!(completed_items: task_run.completed_items + (success ? 1 : 0), failed_items: task_run.failed_items + (success ? 0 : 1), remaining_time_anchor_at: Time.current, last_heartbeat_at: Time.current)
  end

  def cancel_requested? = task_run.reload.cancel_requested?
  def complete!(result) = finish!("completed", result)
  def cancel!(result) = finish!("cancelled", result)
  def fail!(message, result: nil) = finish!("failed", result, message)

  private

  attr_reader :task_run

  def finish!(status, result, error_message = nil)
    data = task_run.result_data.deep_merge((result || {}).deep_stringify_keys)
    data.delete("active_execution_job_id")
    data["progress_unit"] = "teams"
    task_run.update!(status:, result_data: data, error_message:, current_item_mlb_id: nil, current_item_label: nil, finished_at: Time.current, last_heartbeat_at: Time.current)
  end
end
