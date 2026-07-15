namespace :mlb_game_details do
  desc "Download and synchronize MLB box scores, lineups, and plate appearances for stored games"
  task :sync, [ :start_date, :end_date ] => :environment do |_task, args|
    start_date = args[:start_date].presence || ENV["START_DATE"].presence
    end_date = args[:end_date].presence || ENV["END_DATE"].presence || start_date
    mlb_game_id = ENV["MLB_GAME_ID"].presence

    if start_date.blank? && mlb_game_id.blank?
      abort "Usage: bin/rails 'mlb_game_details:sync[2026-07-01,2026-07-07]' or MLB_GAME_ID=823443 bin/rails mlb_game_details:sync"
    end

    target = mlb_game_id.present? ? "MLB game #{mlb_game_id}" : "#{start_date}-#{end_date}"
    puts "Synchronizing MLB game details for #{target}..."
    result = MlbGameDetailsBatchSync.call(
      start_date: start_date,
      end_date: end_date,
      mlb_game_id: mlb_game_id
    )

    unless result[:success]
      Array(result.dig(:data, :errors)).each { |error| warn "- #{error.is_a?(Hash) ? error[:message] : error}" }
      abort result[:message]
    end

    data = result.fetch(:data)
    puts result[:message]
    puts "Batting lines: #{data[:batting_line_count]}"
    puts "Pitching lines: #{data[:pitching_line_count]}"
    puts "Lineup entries: #{data[:lineup_entry_count]}"
    puts "Plate appearances: #{data[:plate_appearance_count]}"
    puts "Statcast pitches linked: #{data[:linked_pitch_count]}"
    puts "Failures: #{data[:failed_game_count]}"
  end
end
