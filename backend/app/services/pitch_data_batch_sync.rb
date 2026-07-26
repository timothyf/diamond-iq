class PitchDataBatchSync
  def self.call(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, progress_tracker: nil)
    new(start_date: start_date, end_date: end_date, game_types: game_types, chunk_days: chunk_days, replace_existing: replace_existing, progress_tracker: progress_tracker).call
  end

  def initialize(start_date:, end_date:, game_types:, chunk_days:, replace_existing: false, progress_tracker: nil)
    @start_date = Date.iso8601(start_date.to_s)
    @end_date = Date.iso8601(end_date.to_s)
    @game_types = game_types.to_s
    @chunk_days = Integer(chunk_days, exception: false)
    @replace_existing = ActiveModel::Type::Boolean.new.cast(replace_existing)
    @progress_tracker = progress_tracker
  end

  def call
    chunks = date_chunks
    games_by_chunk = selected_games_by_chunk
    summary = {
      downloaded_count: 0,
      imported_count: 0,
      duplicate_count: 0,
      skipped_count: 0,
      already_complete_game_count: already_complete_games.count,
      cancelled: false,
      chunk_count: chunks.length,
      game_count: games_by_chunk.values.sum(&:length),
      progress_unit: "games",
      errors: []
    }
    progress_tracker&.start!(total: summary[:game_count])

    chunks.each do |chunk_start, chunk_end|
      if progress_tracker&.cancel_requested?
        summary[:cancelled] = true
        break
      end

      targeted_games = games_by_chunk.fetch([chunk_start, chunk_end], [])
      next if targeted_games.empty?

      download_result = download_chunk(chunk_start:, chunk_end:)
      unless download_result[:success]
        summary[:errors] << { chunk: "#{chunk_start.iso8601} — #{chunk_end.iso8601}", message: download_result[:message], errors: Array(download_result.dig(:data, :errors)) }
        progress_tracker&.chunk_finished!(
          success: false,
          processed_game_count: targeted_games.length,
          result_data: { progress_unit: "games" },
          message: download_result[:message]
        )
        next
      end

      rows_by_game_pk = group_rows_by_game_pk(download_result.dig(:data, :rows) || [])

      targeted_games.each do |game|
        if progress_tracker&.cancel_requested?
          summary[:cancelled] = true
          break
        end

        progress_tracker&.game_started!(game)
        result = sync_game_rows(game: game, rows: rows_by_game_pk.fetch(game.mlb_id, []), chunk_start: chunk_start, chunk_end: chunk_end)
        if result[:success]
          summary[:downloaded_count] += result.dig(:data, :downloaded_count).to_i
          summary[:imported_count] += result.dig(:data, :imported_count).to_i
          summary[:duplicate_count] += result.dig(:data, :duplicate_count).to_i
          summary[:skipped_count] += result.dig(:data, :skipped_count).to_i
        else
          summary[:errors] << { game_pk: game.mlb_id, message: result[:message], errors: Array(result.dig(:data, :errors)) }
        end

        progress_tracker&.chunk_finished!(
          success: result[:success],
          processed_game_count: 1,
          result_data: (result[:data] || {}).merge(progress_unit: "games"),
          message: result[:message]
        )
      end

      break if summary[:cancelled]
    end

    if summary[:cancelled]
      success("Cancelled after processing #{summary[:downloaded_count]} Statcast rows", summary)
    elsif summary[:errors].any? && summary[:imported_count].zero?
      failure("Unable to synchronize Statcast pitch data for any chunk", summary[:errors], summary)
    else
      success("Synchronized #{summary[:imported_count]} pitch data rows across #{chunks.length} chunk#{'s' unless chunks.length == 1}", summary)
    end
  rescue Date::Error
    failure("Pitch data sync received invalid dates", ["Invalid dates"], {})
  end

  private

  attr_reader :start_date, :end_date, :game_types, :chunk_days, :replace_existing, :progress_tracker

  def download_chunk(chunk_start:, chunk_end:)
    PitchDataDownloader.call(
      start_date: chunk_start,
      end_date: chunk_end,
      game_types: game_types,
      chunk_days: ((chunk_end - chunk_start).to_i + 1)
    )
  end

  def sync_game_rows(game:, rows:, chunk_start:, chunk_end:)
    return failure("No pitch data rows were returned for stored game #{game.mlb_id}", [], { downloaded_count: 0, imported_count: 0, duplicate_count: 0, skipped_count: 0 }) if rows.empty?

    import_result = PitchDataImporter.import_raw_rows(
      rows: rows,
      source_name: "Baseball Savant pitch data #{chunk_start.iso8601}-#{chunk_end.iso8601}",
      replace_game_id: (game.id if replace_existing)
    )
    return import_result unless import_result[:success]

    game.update!(pitch_data_complete_at: Time.current, pitch_data_row_count: PitchDatum.where(game_id: game.id).count)

    { success: true, message: import_result[:message], data: import_result[:data].merge(downloaded_count: rows.length) }
  end

  def date_chunks
    chunks = []
    chunk_start = start_date

    while chunk_start <= end_date
      chunk_end = [chunk_start + chunk_days.days - 1.day, end_date].min
      chunks << [chunk_start, chunk_end]
      chunk_start = chunk_end + 1.day
    end

    chunks
  end

  def selected_games_by_chunk
    selected_games.group_by do |game|
      chunk_start = game.official_date
      days_from_start = (chunk_start - start_date).to_i
      offset = days_from_start % chunk_days
      actual_start = chunk_start - offset.days
      actual_end = [actual_start + chunk_days.days - 1.day, end_date].min
      [actual_start, actual_end]
    end
  end

  def group_rows_by_game_pk(rows)
    rows.group_by { |row| Integer(row["game_pk"], exception: false) }
  end

  def selected_games
    @selected_games ||= (replace_existing ? base_games : base_games.where(pitch_data_complete_at: nil)).to_a
  end

  def already_complete_games
    @already_complete_games ||= replace_existing ? Game.none : base_games.where.not(pitch_data_complete_at: nil)
  end

  def base_games
    @base_games ||= Game.where(official_date: start_date..end_date, game_type: game_types.split(","))
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [], data = {})
    { success: false, message: message, data: data.merge(errors: errors) }
  end
end
