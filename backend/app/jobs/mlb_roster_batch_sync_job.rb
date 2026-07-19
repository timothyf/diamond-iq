class MlbRosterBatchSyncJob < ApplicationJob
  queue_as :default

  def perform(task_run_id)
    run = AdminTaskRun.find(task_run_id)
    run.update!(result_data: run.result_data.to_h.merge("active_execution_job_id" => job_id), started_at: run.started_at || Time.current, last_heartbeat_at: Time.current)
    tracker = MlbRosterSyncProgressTracker.new(run)
    parameters = run.task_parameters.symbolize_keys
    as_of = MlbRosterSyncBoundary.call(season: parameters[:season], team_mlb_id: parameters[:team_scope] == "team" ? parameters[:team_mlb_id] : nil)
    result = MlbRosterBatchSync.call(scope: parameters[:team_scope], team_mlb_id: parameters[:team_mlb_id], season: parameters[:season], as_of:, progress_tracker: tracker)
    if result.dig(:data, :cancelled)
      tracker.cancel!(result.fetch(:data))
    elsif result[:success]
      tracker.complete!(result.fetch(:data))
    else
      tracker.fail!(result[:message], result: result[:data])
    end
    result
  rescue StandardError => error
    tracker&.fail!(error.message)
    raise
  end
end
