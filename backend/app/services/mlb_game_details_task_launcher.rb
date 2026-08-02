class MlbGameDetailsTaskLauncher
  EnqueueFailure = Class.new(StandardError)
  TASK_NAME = MlbGameDetailsTaskEstimate::TASK_NAME

  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil, initiated_by: nil)
    new(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id, initiated_by:).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil, initiated_by: nil)
    @start_date_input = start_date
    @end_date_input = end_date
    @mlb_game_id_input = mlb_game_id
    @initiated_by = initiated_by
  end

  def call
    estimate = MlbGameDetailsTaskEstimate.call(
      start_date: start_date_input,
      end_date: end_date_input,
      mlb_game_id: mlb_game_id_input
    )
    attributes = estimate.fetch(:task_parameters)
    if AdminTaskRun.active.exists?(task_name: TASK_NAME)
      raise ArgumentError, "A game detail synchronization is already queued or running"
    end

    task_run = AdminTaskRun.create!(
      task_name: TASK_NAME,
      task_parameters: attributes,
      total_items: estimate.fetch(:game_count),
      estimated_duration_seconds: estimate.fetch(:estimated_seconds),
      initiated_by: @initiated_by
    )
    enqueued_job = MlbGameDetailsSyncJob.perform_later(task_run.id)
    raise EnqueueFailure, "Game detail synchronization could not be enqueued" unless enqueued_job

    task_run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "A game detail synchronization is already queued or running"
  rescue StandardError => error
    if enqueue_error?(error)
      task_run&.update(status: "failed", error_message: error.message, finished_at: Time.current)
    end

    raise
  end

  private

  attr_reader :start_date_input, :end_date_input, :mlb_game_id_input

  def enqueue_error?(error)
    error.is_a?(EnqueueFailure) || error.is_a?(SolidQueue::Job::EnqueueError) || error.class.name == "ActiveJob::EnqueueError"
  end
end
