class MlbRosterSync
  def self.call(team_mlb_id:, season: Date.current.year, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current)
    download_result = MlbRosterDownloader.call(
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of
    )
    return download_result unless download_result[:success]

    data = download_result.fetch(:data)
    MlbRosterImporter.call(
      payload: data.fetch(:payload),
      team_mlb_id: data.fetch(:team_mlb_id),
      season: data.fetch(:season),
      roster_type: data.fetch(:roster_type),
      as_of: data.fetch(:as_of),
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at)
    )
  end
end
