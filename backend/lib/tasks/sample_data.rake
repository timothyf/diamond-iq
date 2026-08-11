namespace :sample_data do
  desc "Bootstrap real MLB sample data for Apr-May 2025 and Apr-May 2026. DRY_RUN=1 previews the plan."
  task bootstrap: :environment do
    result = SampleDataBootstrap.call(
      replace_existing: ENV["REPLACE_EXISTING"],
      worker_count: ENV["WORKER_COUNT"],
      skip_season_stats: ENV["SKIP_SEASON_STATS"],
      skip_profiles: ENV["SKIP_PROFILES"],
      skip_pitch_data: ENV["SKIP_PITCH_DATA"],
      dry_run: ENV["DRY_RUN"]
    )

    abort result[:message] unless result[:success]

    puts result[:message]
    result.fetch(:data).fetch(:periods).each do |period|
      puts "- #{period.fetch(:start_date)} through #{period.fetch(:end_date)}"
    end
    result.dig(:data, :stages)&.each { |stage| puts "- #{stage.fetch(:name)}" }
  end
end
