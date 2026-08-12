class PitchDataSyncJob < ApplicationJob
  queue_as :default

  retry_on StandardError,
    wait: NineLensConfig.fetch(:operations, :pitch_data, :retry_wait_seconds).to_i.seconds,
    attempts: NineLensConfig.fetch(:operations, :pitch_data, :retry_attempts).to_i do |job, error|
    task_run = AdminTaskRun.find_by(id: job.arguments.first)
    PitchDataSyncProgressTracker.new(task_run).fail!(error.message) if task_run
  end

  def perform(task_run_id)
    task_run = AdminTaskRun.find(task_run_id)
    record_execution_claim(task_run)
    tracker = PitchDataSyncProgressTracker.new(task_run)
    parameters = task_run.task_parameters.symbolize_keys
    result = PitchDataBatchSync.call(**parameters, progress_tracker: tracker)

    if result.dig(:data, :cancelled)
      tracker.cancel!(result.fetch(:data))
    elsif result[:success]
      tracker.complete!(result.fetch(:data))
    else
      raise result[:message]
    end

    result
  end

  private

  def record_execution_claim(task_run)
    task_run.with_lock do
      result_data = task_run.result_data.to_h.deep_dup
      result_data["active_execution_job_id"] = job_id
      task_run.update!(
        result_data: result_data,
        started_at: task_run.started_at || Time.current,
        last_heartbeat_at: Time.current
      )
    end
  end
end
