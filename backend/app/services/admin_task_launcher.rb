class AdminTaskLauncher
  EnqueueFailure = Class.new(StandardError)

  def self.call(task_name:, params: {}, initiated_by: nil)
    task_name = task_name.to_s
    raise ArgumentError, "Unknown admin task: #{task_name}" unless AdminTaskRunner::TASKS.key?(task_name)
    raise ArgumentError, "#{task_name.humanize} is already queued or running" if AdminTaskRun.active.exists?(task_name:)

    run = AdminTaskRun.create!(
      task_name:,
      task_parameters: params.to_h,
      total_items: 1,
      current_item_label: AdminTaskRunner::TASKS.fetch(task_name).fetch(:name),
      initiated_by:
    )
    job = AdminTaskJob.perform_later(run.id)
    raise EnqueueFailure, "#{task_name.humanize} could not be enqueued" unless job

    run
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "#{task_name.humanize} is already queued or running"
  rescue StandardError => error
    if enqueue_error?(error)
      run&.update(status: "failed", error_message: error.message, failed_items: 1, finished_at: Time.current)
    end
    raise
  end

  def self.enqueue_error?(error)
    error.is_a?(EnqueueFailure) ||
      error.is_a?(SolidQueue::Job::EnqueueError) ||
      error.class.name == "ActiveJob::EnqueueError"
  end
  private_class_method :enqueue_error?
end
