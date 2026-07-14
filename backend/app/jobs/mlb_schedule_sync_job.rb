class MlbScheduleSyncJob < ApplicationJob
  queue_as :default

  def perform(start_date:, end_date:, game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES, sport_id: 1)
    result = MlbScheduleSync.call(
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      sport_id: sport_id
    )

    raise "MLB schedule synchronization failed: #{result[:message]}" unless result[:success]

    result
  end
end
