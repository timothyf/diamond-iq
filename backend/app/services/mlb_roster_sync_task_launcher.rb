class MlbRosterSyncTaskLauncher
  EnqueueFailure = Class.new(StandardError)
  TASK_NAME = MlbRosterSyncTaskEstimate::TASK_NAME

  def self.call(team_scope:, team_mlb_id: nil, season: Date.current.year, initiated_by: nil)
    estimate = MlbRosterSyncTaskEstimate.call(team_scope:, team_mlb_id:, season:)
    raise ArgumentError, "A roster synchronization is already queued or running" if AdminTaskRun.active.exists?(task_name: TASK_NAME)

    run = AdminTaskRun.create!(task_name: TASK_NAME, task_parameters: estimate.fetch(:task_parameters), total_items: estimate.fetch(:team_count), estimated_duration_seconds: estimate.fetch(:estimated_seconds), initiated_by:)
    job = MlbRosterBatchSyncJob.perform_later(run.id)
    raise EnqueueFailure, "Roster synchronization could not be enqueued" unless job
    run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "A roster synchronization is already queued or running"
  rescue StandardError => error
    run&.update(status: "failed", error_message: error.message, finished_at: Time.current) if error.is_a?(EnqueueFailure) || error.is_a?(SolidQueue::Job::EnqueueError) || error.class.name == "ActiveJob::EnqueueError"
    raise
  end
end
