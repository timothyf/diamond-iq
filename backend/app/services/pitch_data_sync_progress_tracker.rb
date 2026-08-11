class PitchDataSyncProgressTracker
  def initialize(task_run)
    @task_run = task_run
  end

  def start!(total:)
    execution_job_id = task_run.result_data.to_h["active_execution_job_id"]
    result_data = { "progress_phase" => "downloading" }
    result_data["active_execution_job_id"] = execution_job_id if execution_job_id.present?
    task_run.update!(
      status: "running",
      total_items: total,
      completed_items: 0,
      failed_items: 0,
      result_data: result_data,
      error_message: nil,
      current_item_mlb_id: nil,
      current_item_label: nil,
      remaining_time_anchor_at: nil,
      started_at: task_run.started_at || Time.current,
      finished_at: nil,
      last_heartbeat_at: Time.current
    )
  end

  def chunk_started!(chunk_start:, chunk_end:, targeted_game_count:)
    task_run.update!(
      current_item_label: "#{chunk_start.iso8601} — #{chunk_end.iso8601} · #{targeted_game_count} #{targeted_game_count == 1 ? 'game' : 'games'}",
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

  def chunk_finished!(success:, processed_game_count:, result_data: {}, message: nil)
    task_run.with_lock do
      task_run.reload
      merged_result = task_run.result_data.deep_dup
      merged_result["imported_count"] = merged_result.fetch("imported_count", 0) + result_data.fetch(:imported_count, 0)
      merged_result["downloaded_count"] = merged_result.fetch("downloaded_count", 0) + result_data.fetch(:downloaded_count, 0)
      merged_result["duplicate_count"] = merged_result.fetch("duplicate_count", 0) + result_data.fetch(:duplicate_count, 0)
      merged_result["skipped_count"] = merged_result.fetch("skipped_count", 0) + result_data.fetch(:skipped_count, 0)
      merged_result["progress_unit"] = result_data.fetch(:progress_unit, merged_result["progress_unit"])
      unless success
        failures = Array(merged_result["failures"])
        failures << { "message" => message, "chunk" => task_run.current_item_label }
        merged_result["failures"] = failures
      end

      task_run.update!(
        completed_items: task_run.completed_items + (success ? processed_game_count : 0),
        failed_items: task_run.failed_items + (success ? 0 : processed_game_count),
        result_data: merged_result,
        remaining_time_anchor_at: Time.current,
        last_heartbeat_at: Time.current
      )
    end
  end

  def cancel_requested?
    task_run.reload.cancel_requested?
  end

  def analytics_started!
    task_run.update!(
      current_item_mlb_id: nil,
      current_item_label: "Refreshing daily analytics",
      result_data: task_run.result_data.to_h.merge("progress_phase" => "analytics"),
      last_heartbeat_at: Time.current
    )
  end

  def analytics_finished!(result = nil)
    result_data = task_run.result_data.to_h.merge("progress_phase" => "complete")
    result_data["analytics_refresh"] = result.deep_stringify_keys if result
    task_run.update!(result_data: result_data, last_heartbeat_at: Time.current)
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
    result_data = task_run.result_data.deep_merge((result || {}).deep_stringify_keys)
    result_data.delete("active_execution_job_id")
    task_run.update!(
      status: status,
      result_data: result_data,
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
