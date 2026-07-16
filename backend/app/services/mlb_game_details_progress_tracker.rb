class MlbGameDetailsProgressTracker
  def initialize(task_run)
    @task_run = task_run
  end

  def start!(total:)
    task_run.update!(
      status: "running",
      total_items: total,
      completed_items: 0,
      failed_items: 0,
      result_data: {},
      error_message: nil,
      current_item_mlb_id: nil,
      current_item_label: nil,
      started_at: task_run.started_at || Time.current,
      finished_at: nil,
      last_heartbeat_at: Time.current
    )
  end

  def game_started!(game)
    task_run.update!(
      current_item_mlb_id: game.mlb_id,
      current_item_label: game_label(game),
      last_heartbeat_at: Time.current
    )
  end

  def game_finished!(game:, success:, message: nil)
    task_run.with_lock do
      task_run.reload
      result_data = task_run.result_data.deep_dup
      unless success
        failures = Array(result_data["failures"])
        failures << { "mlb_id" => game.mlb_id, "message" => message }
        result_data["failures"] = failures
      end
      task_run.update!(
        completed_items: task_run.completed_items + (success ? 1 : 0),
        failed_items: task_run.failed_items + (success ? 0 : 1),
        result_data: result_data,
        last_heartbeat_at: Time.current
      )
    end
  end

  def cancel_requested?
    task_run.reload.cancel_requested?
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

  attr_reader :task_run

  def finish!(status:, result:, error_message: nil)
    task_run.update!(
      status: status,
      result_data: task_run.result_data.deep_merge((result || {}).deep_stringify_keys),
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
end
