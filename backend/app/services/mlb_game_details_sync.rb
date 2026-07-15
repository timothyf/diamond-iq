class MlbGameDetailsSync
  def self.call(game:)
    download_result = MlbGameDetailsDownloader.call(mlb_id: game.mlb_id)
    return download_result unless download_result[:success]

    data = download_result.fetch(:data)
    MlbGameDetailsImporter.call(
      game: game,
      boxscore: data.fetch(:boxscore),
      live_feed: data.fetch(:live_feed),
      boxscore_source_url: data.fetch(:boxscore_source_url),
      live_feed_source_url: data.fetch(:live_feed_source_url),
      fetched_at: data.fetch(:fetched_at)
    )
  end
end
