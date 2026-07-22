require "fileutils"
require "json"

namespace :storage do
  desc "Audit PostgreSQL storage: database size, table sizes, row counts, and JSON payload sizes"
  task audit: :environment do
    report = StorageAudit.call
    output_path = storage_output_path("audit")

    write_report(output_path, report)
    print_audit_summary(report)
    puts "Saved audit report to #{output_path}"
  end

  desc "Create a PostgreSQL custom-format backup in tmp/storage_baselines/backups"
  task backup: :environment do
    result = StorageBackup.call(output_path: ENV["OUTPUT"].presence)
    puts "Backup created: #{result[:backup_path]}"
    puts "Size: #{result[:backup_pretty]} (#{result[:backup_bytes]} bytes)"
    puts "SHA-256: #{result[:backup_sha256]}"
    puts "Archive verified: #{result[:archive_verified]}"
    warn_same_filesystem(result)
  end

  desc "Restore a backup into a temporary database and verify row counts (BACKUP=path required)"
  task restore_test: :environment do
    backup_path = ENV.fetch("BACKUP") { abort "Usage: bin/rails storage:restore_test BACKUP=path/to/backup.dump" }
    result = StorageRestoreTest.call(backup_path: backup_path)

    puts "Restore verification passed for #{result[:backup_path]}"
    puts "Source database: #{result[:source_database]}"
    puts "Temporary restore database: #{result[:restore_database]}"
    puts "Row-count checksum: #{result[:source_row_count_checksum]}"
    puts "Content checksum: #{result[:source_content_checksum]}"
    puts "Schema checksum: #{result[:source_schema_checksum]}"
  end

  desc "Run baseline safety checks with writers stopped (requires WRITERS_STOPPED=1)"
  task baseline: :environment do
    unless ENV["WRITERS_STOPPED"] == "1"
      abort <<~MESSAGE
        Refusing to create a baseline while database writers may be active.
        Stop Rails processes, importers, and Solid Queue workers, then run:
          WRITERS_STOPPED=1 bin/rails storage:baseline
      MESSAGE
    end

    FileUtils.mkdir_p(Rails.root.join("tmp/storage_baselines"))

    puts "== Storage baseline: audit =="
    audit_report = StorageAudit.call
    audit_path = storage_output_path("audit")
    write_report(audit_path, audit_report)
    print_audit_summary(audit_report)

    puts "\n== Storage baseline: backup =="
    backup_result = StorageBackup.call(output_path: ENV["OUTPUT"].presence)
    puts "Backup created: #{backup_result[:backup_path]}"
    puts "Size: #{backup_result[:backup_pretty]}"
    puts "SHA-256: #{backup_result[:backup_sha256]}"
    puts "Archive verified: #{backup_result[:archive_verified]}"
    warn_same_filesystem(backup_result)

    puts "\n== Storage baseline: restore test =="
    restore_result = StorageRestoreTest.call(backup_path: backup_result[:backup_path])
    puts "Restore verification passed"
    puts "Row-count checksum: #{restore_result[:source_row_count_checksum]}"
    puts "Content checksum: #{restore_result[:source_content_checksum]}"
    puts "Schema checksum: #{restore_result[:source_schema_checksum]}"

    baseline_report = {
      created_at: Time.current.iso8601,
      rails_env: Rails.env,
      audit: audit_report,
      backup: backup_result,
      restore_test: restore_result
    }

    baseline_path = storage_output_path("baseline")
    write_report(baseline_path, baseline_report)

    puts "\n== Baseline complete =="
    puts "Audit report: #{audit_path}"
    puts "Baseline report: #{baseline_path}"
    puts "Backup file: #{backup_result[:backup_path]}"
    puts "Integrity checksum: #{audit_report[:integrity_checksum]}"

    unless audit_report.dig(:rewrite_readiness, :ready_for_table_rewrite)
      puts "\nWARNING: Available disk space may be insufficient for later VACUUM FULL table rewrites."
      puts "Recommended free space: #{audit_report.dig(:rewrite_readiness, :recommended_free_pretty)}"
      puts "Available at PostgreSQL data path: #{audit_report.dig(:rewrite_readiness, :database_directory_available_pretty)}"
    end
  end

  def storage_output_path(kind)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    Rails.root.join("tmp/storage_baselines/#{kind}_#{Rails.env}_#{timestamp}.json")
  end

  def write_report(path, payload)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(payload))
  end

  def print_audit_summary(report)
    puts "Database: #{report[:database]} (#{report[:database_size_pretty]})"
    puts "Integrity checksum: #{report[:integrity_checksum]}"
    puts "Archival JSON payload: #{report.dig(:archival_json_columns, :total_pretty)}"
    puts "Estimated post-archival size: #{report.dig(:migration_targets, :expected_post_archival_database_size_pretty)}"
    puts
    puts "Top tables by total size:"
    report.fetch(:tables).first(10).each do |table|
      puts "  #{table[:table_name].ljust(32)} #{table[:total_pretty]}"
    end
    puts
    puts "Archival JSON columns:"
    report.dig(:archival_json_columns, :columns).each do |column|
      puts "  #{column[:table_name]}.#{column[:column_name].ljust(22)} #{column[:payload_pretty]}"
    end
    puts
    puts "Critical row counts:"
    report.fetch(:critical_row_counts).sort.each do |table_name, count|
      puts "  #{table_name.ljust(32)} #{count}"
    end
  end

  def warn_same_filesystem(result)
    return unless result[:same_filesystem_as_database]

    puts "WARNING: This backup is on the same filesystem as PostgreSQL."
    puts "Copy it off-machine and verify its SHA-256 before destructive table rewrites."
  end
end
