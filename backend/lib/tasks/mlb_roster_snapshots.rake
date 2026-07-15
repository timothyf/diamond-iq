namespace :mlb_roster_snapshots do
  desc "Store independent MLB Active and 40-man roster snapshots for a team and date"
  task :sync, [ :team_mlb_id, :snapshot_on ] => :environment do |_task, args|
    team_mlb_id = args[:team_mlb_id].presence || ENV["TEAM_MLB_ID"]
    snapshot_on = args[:snapshot_on].presence || ENV["SNAPSHOT_ON"]

    abort "Usage: bin/rails 'mlb_roster_snapshots:sync[TEAM_MLB_ID,YYYY-MM-DD]'" if team_mlb_id.blank? || snapshot_on.blank?

    result = MlbRosterSnapshotSync.call(team_mlb_id: team_mlb_id, snapshot_on: snapshot_on)
    abort result[:message] unless result[:success]

    puts result[:message]
    result.fetch(:data).fetch(:player_counts).each do |roster_type, count|
      puts "#{roster_type}: #{count} players"
    end
  end
end
