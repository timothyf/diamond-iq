class MlbScheduleSync
  def self.call(start_date:, end_date:, game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES, sport_id: 1)
    download_result = MlbScheduleDownloader.call(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      sport_id: sport_id
    )
    return download_result unless download_result[:success]

    data = download_result.fetch(:data)
    MlbScheduleImporter.call(
      payload: data.fetch(:payload),
      start_date: data.fetch(:start_date),
      end_date: data.fetch(:end_date),
      game_types: data.fetch(:game_types),
      sport_id: data.fetch(:sport_id),
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at)
    )
  end
end
