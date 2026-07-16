class MlbGameDetailsSyncJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3 do |job, error|
    task_run = AdminTaskRun.find_by(id: job.arguments.first)
    MlbGameDetailsProgressTracker.new(task_run).fail!(error.message) if task_run
  end

  def perform(task_run_id)
    task_run = AdminTaskRun.find(task_run_id)
    tracker = MlbGameDetailsProgressTracker.new(task_run)
    parameters = task_run.task_parameters.symbolize_keys
    result = MlbGameDetailsBatchSync.call(**parameters, progress_tracker: tracker)

    if result.dig(:data, :cancelled)
      tracker.cancel!(result.fetch(:data))
    elsif result[:success]
      tracker.complete!(result.fetch(:data))
    else
      raise result[:message]
    end

    result
  end
end
