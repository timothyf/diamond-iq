class MlbGameDetailsSyncJob < ApplicationJob
  queue_as :default

  def perform(start_date: nil, end_date: nil, mlb_game_id: nil)
    result = MlbGameDetailsBatchSync.call(start_date: start_date, end_date: end_date, mlb_game_id: mlb_game_id)
    raise result[:message] unless result[:success]

    result
  end
end
