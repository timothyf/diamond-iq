class MlbGameDetailsBatchSync
  def self.call(start_date: nil, end_date: nil, mlb_game_id: nil, progress_tracker: nil)
    new(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id, progress_tracker: progress_tracker).call
  end

  def initialize(start_date: nil, end_date: nil, mlb_game_id: nil, progress_tracker: nil)
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @mlb_game_id_provided = mlb_game_id.present?
    @mlb_game_id = Integer(mlb_game_id, exception: false) if mlb_game_id.present?
    @progress_tracker = progress_tracker
  end

  def call
    errors = validation_errors
    return failure(errors.first, errors) if errors.any?

    games = selected_games.to_a
    summary = empty_summary.merge(game_count: games.length)
    failures = []
    progress_tracker&.start!(total: games.length)

    games.each do |game|
      if progress_tracker&.cancel_requested?
        summary[:cancelled] = true
        break
      end

      progress_tracker&.game_started!(game)
      result = MlbGameDetailsSync.call(game: game)
      if result[:success]
        accumulate!(summary, result.fetch(:data))
        summary[:synchronized_game_count] += 1
      else
        summary[:failed_game_count] += 1
        failures << { mlb_id: game.mlb_id, message: result[:message], errors: Array(result.dig(:data, :errors)) }
      end
      progress_tracker&.game_finished!(game: game, success: result[:success], message: result[:message])
    end

    summary[:errors] = failures
    if summary[:cancelled]
      processed = summary[:synchronized_game_count] + summary[:failed_game_count]
      return success("Cancelled after processing #{processed} of #{games.length} MLB games", summary)
    end

    if games.any? && summary[:synchronized_game_count].zero?
      failure("Unable to synchronize details for any selected MLB games", failures, summary)
    else
      success("Synchronized details for #{summary[:synchronized_game_count]} of #{games.length} MLB games", summary)
    end
  end

  private

  attr_reader :start_date, :end_date, :mlb_game_id, :mlb_game_id_provided, :progress_tracker

  def selected_games
    scope = Game.includes(:away_team, :home_team).order(:official_date, :scheduled_at, :mlb_id)
    return scope.where(mlb_id: mlb_game_id) if mlb_game_id_provided

    scope.where(official_date: start_date..end_date)
  end

  def validation_errors
    errors = []
    if mlb_game_id_provided
      errors << "MLB game id must be a positive integer" unless mlb_game_id&.positive?
      if mlb_game_id&.positive? && !Game.exists?(mlb_id: mlb_game_id)
        errors << "No stored game was found for MLB game id #{mlb_game_id}"
      end
      return errors
    end

    errors << "Start date is required" if start_date.nil?
    errors << "End date is required" if end_date.nil?
    errors << "End date must be on or after start date" if start_date && end_date && end_date < start_date
    errors
  end

  def empty_summary
    {
      game_count: 0,
      synchronized_game_count: 0,
      failed_game_count: 0,
      batting_line_count: 0,
      pitching_line_count: 0,
      lineup_entry_count: 0,
      plate_appearance_count: 0,
      created_player_count: 0,
      linked_pitch_count: 0,
      cancelled: false
    }
  end

  def accumulate!(summary, data)
    empty_summary.except(:game_count, :synchronized_game_count, :failed_game_count, :cancelled).each_key do |key|
      summary[key] += data.fetch(key, 0)
    end
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [], summary = {})
    { success: false, message: message, data: summary.merge(errors: errors) }
  end
end
