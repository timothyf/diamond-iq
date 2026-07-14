namespace :player_positions do
  desc "Backfill normalized current player positions from team memberships"
  task backfill_from_team_memberships: :environment do
    result = PlayerPositionsBackfill.call

    puts result[:message]
    puts result[:data].inspect

    abort(result[:message]) unless result[:success]
  end
end
