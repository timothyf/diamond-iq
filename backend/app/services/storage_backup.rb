require "digest"
require "fileutils"
require "open3"
require "shellwords"

class StorageBackup
  class Error < StandardError; end

  def self.call(database: nil, output_path: nil, postgres_connection: StoragePostgresConnection.new)
    new(database: database, output_path: output_path, postgres_connection: postgres_connection).call
  end

  def initialize(database:, output_path:, postgres_connection:)
    @postgres_connection = postgres_connection
    @database = database.presence || postgres_connection.database
    @output_path = output_path
  end

  def call
    dump_path = Pathname.new(output_path || default_output_path)
    FileUtils.mkdir_p(dump_path.dirname)

    stdout, stderr, status = Open3.capture3(postgres_connection.environment, *dump_command(dump_path))
    raise Error, "pg_dump failed: #{stderr.presence || stdout}" unless status.success?
    raise Error, "Backup file was not created at #{dump_path}" unless File.exist?(dump_path)

    verify_archive!(dump_path)

    {
      database: database,
      backup_path: dump_path.to_s,
      backup_bytes: File.size(dump_path),
      backup_pretty: ActiveSupport::NumberHelper.number_to_human_size(File.size(dump_path)),
      backup_sha256: Digest::SHA256.file(dump_path).hexdigest,
      archive_verified: true,
      same_filesystem_as_database: same_filesystem_as_database?(dump_path),
      created_at: Time.current.iso8601
    }
  end

  private

  attr_reader :database, :output_path, :postgres_connection

  def backup_directory
    Rails.root.join("tmp/storage_baselines/backups")
  end

  def default_output_path
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_directory.join("#{database}_#{timestamp}.dump")
  end

  def dump_command(dump_path)
    [
      "pg_dump",
      "--format=custom",
      "--no-owner",
      "--no-acl",
      "--file=#{dump_path}",
      *postgres_connection.arguments(database: database)
    ]
  end

  def verify_archive!(dump_path)
    stdout, stderr, status = Open3.capture3(
      postgres_connection.environment,
      "pg_restore",
      "--list",
      dump_path.to_s
    )
    raise Error, "Backup archive validation failed: #{stderr.presence || stdout}" unless status.success?
  end

  def same_filesystem_as_database?(dump_path)
    data_directory = ActiveRecord::Base.connection.select_value("SHOW data_directory")
    return nil unless File.exist?(data_directory)

    File.stat(dump_path).dev == File.stat(data_directory).dev
  rescue SystemCallError
    nil
  end
end
