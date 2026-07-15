namespace :mlb_roster do
  desc "Synchronize one MLB team's roster through season end or today. Usage: bin/rails 'mlb_roster:sync[116,2026]' ROSTER_TYPE=40Man"
  task :sync, [ :team_mlb_id, :season ] => :environment do |_task, args|
    team_mlb_id = args[:team_mlb_id].presence || ENV["TEAM_MLB_ID"].presence
    season = args[:season].presence || ENV["SEASON"].presence || Date.current.year
    season = Integer(season, exception: false)
    roster_type = ENV["ROSTER_TYPE"].presence || MlbRosterDownloader::DEFAULT_ROSTER_TYPE

    abort "Usage: bin/rails 'mlb_roster:sync[116,2026]' or TEAM_MLB_ID=116 SEASON=2026 bin/rails mlb_roster:sync" if team_mlb_id.blank?
    as_of = MlbRosterSyncBoundary.call(season: season)

    puts "Synchronizing #{roster_type} roster for MLB team #{team_mlb_id} through #{as_of}..."
    result = MlbRosterSync.call(
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of
    )

    unless result[:success]
      Array(result.dig(:data, :errors)).each { |error| warn "- #{error}" }
      abort result[:message]
    end

    data = result.fetch(:data)
    puts result[:message]
    puts "Created players: #{data[:created_player_count]}"
    puts "Created profiles: #{data[:created_profile_count]}"
    puts "Created memberships: #{data[:created_membership_count]}"
    puts "Updated memberships: #{data[:updated_membership_count]}"
    puts "Closed memberships: #{data[:closed_membership_count]}"
  end
end
