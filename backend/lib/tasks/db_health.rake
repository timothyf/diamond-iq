require "json"

namespace :db_health do
  desc "Run the Admin data-health checks (FORMAT=json for JSON, STRICT=1 to fail on warnings)"
  task check: :environment do
    format = ENV.fetch("FORMAT", "text").downcase
    abort "FORMAT must be either text or json" unless %w[text json].include?(format)

    if format == "text"
      puts "Running NineLens database health check..."
      $stdout.flush
    end

    report = AdminDataHealthCheck.call

    if format == "json"
      puts JSON.pretty_generate(report)
    else
      summary = report.fetch(:summary)

      puts
      puts "Database health: #{report.fetch(:status).upcase}"
      puts "Checked at: #{report.fetch(:checked_at).iso8601}"
      puts "Calculation version: #{report.fetch(:calculation_version)}"
      puts format(
        "Summary: %d healthy, %d warnings, %d critical (%d affected records across %d checks)",
        summary.fetch(:healthy_count),
        summary.fetch(:warning_count),
        summary.fetch(:critical_count),
        summary.fetch(:affected_record_count),
        summary.fetch(:check_count)
      )
      puts

      markers = { "healthy" => "✓", "warning" => "!", "critical" => "✗" }

      report.fetch(:checks).each do |check|
        status = check.fetch(:status)
        affected_count = check.fetch(:affected_count)
        affected_label = affected_count == 1 ? "record" : "records"

        puts "#{markers.fetch(status)} [#{check.fetch(:category)}] #{check.fetch(:name)} — " \
          "#{status.upcase} (#{affected_count} #{affected_label})"

        next if status == "healthy"

        puts "  #{check.fetch(:description)}"
        Array(check[:examples]).each { |example| puts "  Example: #{example}" }
        puts "  Recommendation: #{check.fetch(:recommendation)}"
      end
    end

    strict = ActiveModel::Type::Boolean.new.cast(ENV["STRICT"])
    failed = report.fetch(:status) == "critical" || (strict && report.fetch(:status) == "warning")
    abort "Database health check failed with status #{report.fetch(:status).upcase}." if failed
  end
end
