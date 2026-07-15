class MlbRosterSyncJob < ApplicationJob
  queue_as :default

  def perform(team_mlb_id:, season: Date.current.year, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current)
    result = MlbRosterSync.call(
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of
    )

    raise "MLB roster synchronization failed: #{result[:message]}" unless result[:success]

    result
  end
end
