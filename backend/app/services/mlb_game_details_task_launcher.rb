class MlbGameDetailsTaskLauncher
  TASK_NAME = "mlb_game_details_sync"

  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil)
    new(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil)
    @start_date_input = start_date
    @end_date_input = end_date
    @mlb_game_id_input = mlb_game_id
  end

  def call
    attributes = normalized_attributes
    if AdminTaskRun.active.exists?(task_name: TASK_NAME)
      raise ArgumentError, "A game detail synchronization is already queued or running"
    end

    task_run = AdminTaskRun.create!(
      task_name: TASK_NAME,
      task_parameters: attributes,
      total_items: selected_games(attributes).count
    )
    enqueued_job = MlbGameDetailsSyncJob.perform_later(task_run.id)
    raise ActiveJob::EnqueueError, "Game detail synchronization could not be enqueued" unless enqueued_job

    task_run
  rescue ActiveJob::EnqueueError, SolidQueue::Job::EnqueueError => error
    task_run&.update(status: "failed", error_message: error.message, finished_at: Time.current)
    raise
  rescue ActiveRecord::RecordNotUnique
    raise ArgumentError, "A game detail synchronization is already queued or running"
  end

  private

  attr_reader :start_date_input, :end_date_input, :mlb_game_id_input

  def normalized_attributes
    if mlb_game_id_input.present?
      mlb_game_id = Integer(mlb_game_id_input, exception: false)
      raise ArgumentError, "MLB game id must be a positive integer" unless mlb_game_id&.positive?
      raise ArgumentError, "No stored game was found for MLB game id #{mlb_game_id}" unless Game.exists?(mlb_id: mlb_game_id)

      return { "mlb_game_id" => mlb_game_id }
    end

    start_date = parse_required_date(:start_date, start_date_input)
    end_date = parse_required_date(:end_date, end_date_input)
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    { "start_date" => start_date.iso8601, "end_date" => end_date.iso8601 }
  end

  def selected_games(attributes)
    return Game.where(mlb_id: attributes.fetch("mlb_game_id")) if attributes["mlb_game_id"]

    Game.where(official_date: Date.iso8601(attributes.fetch("start_date"))..Date.iso8601(attributes.fetch("end_date")))
  end

  def parse_required_date(name, value)
    raise ArgumentError, "#{name.to_s.humanize} is required" if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "#{name.to_s.humanize} must be a valid ISO date"
  end
end
