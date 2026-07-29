class AdminTaskJob < ApplicationJob
  queue_as :default

  def perform(task_run_id)
    run = AdminTaskRun.find(task_run_id)
    return terminal_result(run) if run.terminal?
    return cancel_before_start(run) if run.cancel_requested?

    mark_running(run)
    result = AdminTaskRunner.call(task_name: run.task_name, params: run.task_parameters)

    if result[:success]
      complete(run, result)
    else
      fail_run(run, result[:message], result)
    end

    result
  rescue StandardError => error
    fail_run(run, error.message) if run&.persisted? && !run.terminal?
    { success: false, message: error.message, data: { errors: [ error.message ] } }
  end

  private

  def mark_running(run)
    run.update!(
      status: "running",
      started_at: run.started_at || Time.current,
      last_heartbeat_at: Time.current,
      result_data: run.result_data.to_h.merge("active_execution_job_id" => job_id)
    )
  end

  def complete(run, result)
    run.update!(
      status: "completed",
      completed_items: 1,
      failed_items: 0,
      error_message: nil,
      current_item_label: nil,
      result_data: serialized_result(result),
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
  end

  def fail_run(run, message, result = nil)
    run.update!(
      status: "failed",
      failed_items: 1,
      error_message: message,
      current_item_label: nil,
      result_data: serialized_result(result || { success: false, message: message, data: { errors: [ message ] } }),
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
  end

  def cancel_before_start(run)
    run.update!(
      status: "cancelled",
      current_item_label: nil,
      result_data: { "success" => false, "message" => "Task cancelled before it started", "data" => { "cancelled" => true } },
      last_heartbeat_at: Time.current,
      finished_at: Time.current
    )
    terminal_result(run)
  end

  def terminal_result(run)
    run.result_data.to_h.symbolize_keys
  end

  def serialized_result(result)
    {
      "success" => result[:success],
      "message" => result[:message],
      "data" => result[:data] || {}
    }
  end
end
