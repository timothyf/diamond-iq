class MlbGameDetailsProgressTracker
  def initialize(task_run)
    @task_run_id = task_run.id
  end

  def start!(total:)
    run = current_task_run
    if run.status == "running" && run.started_at.present? && run.processed_items.positive?
      run.update!(
        total_items: [run.total_items, total].max,
        last_heartbeat_at: Time.current
      )
      return
    end

    run.update!(
      status: "running",
      total_items: total,
      completed_items: 0,
      failed_items: 0,
      result_data: run.result_data.presence || {},
      error_message: nil,
      current_item_mlb_id: nil,
      current_item_label: nil,
      started_at: run.started_at || Time.current,
      finished_at: nil,
      last_heartbeat_at: Time.current
    )
  end

  def game_started!(game)
    current_time = Time.current
    AdminTaskRun.where(id: task_run_id).update_all(
      current_item_mlb_id: game.mlb_id,
      current_item_label: game_label(game),
      last_heartbeat_at: current_time,
      updated_at: current_time
    )
  end

  def game_finished!(game:, success:, message: nil)
    AdminTaskRun.transaction do
      run = AdminTaskRun.lock.find(task_run_id)
      processed_items = run.completed_items + run.failed_items
      if run.total_items.positive? && processed_items >= run.total_items
        run.update!(last_heartbeat_at: Time.current)
        return
      end

      result_data = run.result_data.deep_dup
      unless success
        failures = Array(result_data["failures"])
        failures << { "mlb_id" => game.mlb_id, "message" => message }
        result_data["failures"] = failures
      end
      run.update!(
        completed_items: run.completed_items + (success ? 1 : 0),
        failed_items: run.failed_items + (success ? 0 : 1),
        result_data: result_data,
        remaining_time_anchor_at: Time.current,
        last_heartbeat_at: Time.current
      )
    end
  end

  def cancel_requested?
    current_task_run.cancel_requested?
  end

  def complete!(result)
    finish!(status: "completed", result: result)
  end

  def cancel!(result)
    finish!(status: "cancelled", result: result)
  end

  def fail!(message, result: nil)
    finish!(status: "failed", result: result, error_message: message)
  end

  private

  attr_reader :task_run_id

  def finish!(status:, result:, error_message: nil)
    run = current_task_run
    run.update!(
      status: status,
      result_data: run.result_data.deep_merge((result || {}).deep_stringify_keys),
      error_message: error_message,
      current_item_mlb_id: nil,
      current_item_label: nil,
      finished_at: Time.current,
      last_heartbeat_at: Time.current
    )
  end

  def game_label(game)
    matchup = [ game.away_team&.abbreviation, game.home_team&.abbreviation ].compact.join(" at ")
    [ matchup.presence || "MLB game #{game.mlb_id}", game.official_date&.to_fs(:long) ].compact.join(" — ")
  end

  def current_task_run
    AdminTaskRun.find(task_run_id)
  end
end
