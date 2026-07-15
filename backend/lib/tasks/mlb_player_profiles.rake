namespace :mlb_player_profiles do
  desc "Synchronize MLB profiles for existing players. Defaults to players without profiles."
  task sync: :environment do
    only_missing = ENV.fetch("ONLY_MISSING", "true")
    batch_size = ENV.fetch("BATCH_SIZE", MlbPlayerProfilesSync::DEFAULT_BATCH_SIZE)
    limit = ENV["LIMIT"].presence
    mlb_ids = ENV["MLB_IDS"].presence

    puts "Synchronizing MLB player profiles (only_missing=#{only_missing}, batch_size=#{batch_size})..."
    result = MlbPlayerProfilesSync.call(
      only_missing: only_missing,
      batch_size: batch_size,
      limit: limit,
      mlb_ids: mlb_ids
    )

    unless result[:success]
      Array(result.dig(:data, :errors)).each { |error| warn "- #{error}" }
      abort result[:message]
    end

    data = result.fetch(:data)
    puts result[:message]
    puts "Selected players: #{data[:selected_player_count]}"
    puts "Created profiles: #{data[:created_profile_count]}"
    puts "Updated profiles: #{data[:updated_profile_count]}"
    puts "Position assignments: #{data[:position_assignment_count]}"
    puts "MLB ids not returned: #{data[:missing_mlb_ids].join(', ')}" if data[:missing_mlb_ids].any?
  end
end
