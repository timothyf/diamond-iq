class MlbPlayerProfilesSyncJob < ApplicationJob
  queue_as :default

  def perform(only_missing: true, batch_size: MlbPlayerProfilesSync::DEFAULT_BATCH_SIZE, limit: nil, mlb_ids: nil)
    result = MlbPlayerProfilesSync.call(
      only_missing: only_missing,
      batch_size: batch_size,
      limit: limit,
      mlb_ids: mlb_ids
    )

    raise "MLB player profile synchronization failed: #{result[:message]}" unless result[:success]

    result
  end
end
