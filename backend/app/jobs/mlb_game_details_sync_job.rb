class MlbGameDetailsSyncJob < ApplicationJob
  queue_as :default

  def perform(task_run_id)
    claim_state = claim_execution(task_run_id)
    task_run = AdminTaskRun.find(task_run_id)
    return { success: true, message: "Task already finished", data: task_run.result_data } if claim_state == :terminal
    if claim_state == :duplicate
      return { success: true, message: "Task execution already in progress", data: task_run.result_data }
    end

    tracker = MlbGameDetailsProgressTracker.new(task_run)
    if analytics_refresh_interrupted?(task_run)
      result_data = task_run.result_data.to_h.deep_dup
      result_data["analytics_refresh"] = {
        "success" => false,
        "deferred" => true,
        "message" => "Game details synchronized, but analytics refresh was interrupted by a worker restart. Run daily analytics refresh to complete downstream updates."
      }
      result_data["active_execution_job_id"] = nil
      tracker.complete!(result_data)
      return {
        success: true,
        message: "Synchronized game details; analytics refresh deferred after worker restart",
        data: result_data
      }
    end

    parameters = task_run.task_parameters.symbolize_keys
    result = MlbGameDetailsBatchSync.call(**parameters, progress_tracker: tracker)

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
    { success: false, message: error.message, data: { errors: [ error.message ] } }
  ensure
    release_execution_claim(task_run_id)
  end

  private

  def claim_execution(task_run_id)
    AdminTaskRun.transaction do
      task_run = AdminTaskRun.lock.find(task_run_id)
      return :terminal if task_run.terminal?

      result_data = task_run.result_data.deep_dup
      existing_job_id = result_data["active_execution_job_id"]
      recent_heartbeat = task_run.last_heartbeat_at.present? && task_run.last_heartbeat_at > execution_heartbeat_stale_seconds.seconds.ago
      duplicate_running = task_run.status == "running" && existing_job_id.present? && existing_job_id != job_id && recent_heartbeat
      return :duplicate if duplicate_running

      result_data["active_execution_job_id"] = job_id
      task_run.update!(result_data: result_data, started_at: task_run.started_at || Time.current, status: task_run.status.presence || "queued")
      :claimed
    end
  end

  def release_execution_claim(task_run_id)
    AdminTaskRun.transaction do
      task_run = AdminTaskRun.lock.find_by(id: task_run_id)
      return unless task_run

      result_data = task_run.result_data.deep_dup
      return unless result_data["active_execution_job_id"] == job_id

      result_data.delete("active_execution_job_id")
      task_run.update!(result_data: result_data)
    end
  rescue StandardError => error
    Rails.logger.warn("MlbGameDetailsSyncJob claim release skipped for task_run_id=#{task_run_id}: #{error.class}: #{error.message}")
  end

  def execution_heartbeat_stale_seconds
    NineLensConfig.fetch(:operations, :game_details, :execution_heartbeat_stale_seconds).to_i
  end

  def analytics_refresh_interrupted?(task_run)
    return false unless task_run.status == "running"
    return false if task_run.total_items.zero?
    return false if task_run.processed_items < task_run.total_items

    task_run.result_data.to_h["analytics_refresh"].blank?
  end
end
