class PitchDataSyncTaskLauncher
  EnqueueFailure = Class.new(StandardError)
  TASK_NAME = PitchDataSyncTaskEstimate::TASK_NAME

  def self.call(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false)
    new(start_date: start_date, end_date: end_date, game_types: game_types, chunk_days: chunk_days, replace_existing: replace_existing).call
  end

  def initialize(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false)
    @start_date = start_date
    @end_date = end_date
    @game_types = game_types
    @chunk_days = chunk_days
    @replace_existing = replace_existing
  end

  def call
    estimate = PitchDataSyncTaskEstimate.call(start_date: @start_date, end_date: @end_date, game_types: @game_types, chunk_days: @chunk_days, replace_existing: @replace_existing)
    attributes = estimate.fetch(:task_parameters)
    raise ArgumentError, "A Statcast pitch data synchronization is already queued or running" if AdminTaskRun.active.exists?(task_name: TASK_NAME)

    task_run = AdminTaskRun.create!(task_name: TASK_NAME, task_parameters: attributes, total_items: estimate.fetch(:game_count))
    enqueued_job = PitchDataSyncJob.perform_later(task_run.id)
    raise EnqueueFailure, "Statcast pitch data synchronization could not be enqueued" unless enqueued_job

    task_run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "A Statcast pitch data synchronization is already queued or running"
  rescue StandardError => error
    if enqueue_error?(error)
      task_run&.update(status: "failed", error_message: error.message, finished_at: Time.current)
    end

    raise
  end

  private

  def enqueue_error?(error)
    error.is_a?(EnqueueFailure) || error.is_a?(SolidQueue::Job::EnqueueError) || error.class.name == "ActiveJob::EnqueueError"
  end
end
