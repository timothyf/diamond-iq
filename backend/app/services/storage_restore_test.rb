require "digest"
require "open3"
require "securerandom"
require "shellwords"

class StorageRestoreTest
  class Error < StandardError; end

  def self.call(
    backup_path:,
    source_database: nil,
    restore_database: nil,
    postgres_connection: StoragePostgresConnection.new
  )
    new(
      backup_path: backup_path,
      source_database: source_database,
      restore_database: restore_database,
      postgres_connection: postgres_connection
    ).call
  end

  def initialize(backup_path:, source_database:, restore_database:, postgres_connection:)
    @backup_path = Pathname.new(backup_path)
    @postgres_connection = postgres_connection
    @source_database = source_database.presence || postgres_connection.database
    @restore_database = restore_database || default_restore_database_name
    @restore_database_created = false
  end

  def call
    validate_restore_target!
    validate_backup!
    ensure_restore_database_absent!
    create_restore_database
    restore_backup
    compare_restored_database
  ensure
    drop_created_restore_database if restore_database_created? && ENV["KEEP_RESTORE_DATABASE"] != "1"
  end

  private

  attr_reader :backup_path, :source_database, :restore_database, :postgres_connection

  def validate_backup!
    raise Error, "Backup file not found: #{backup_path}" unless backup_path.exist?
  end

  def default_restore_database_name
    "#{restore_database_prefix}#{Process.pid}_#{SecureRandom.hex(4)}"
  end

  def restore_database_prefix
    "#{source_database.gsub(/[^a-zA-Z0-9_]/, "_")}_storage_restore_test_"
  end

  def validate_restore_target!
    unless restore_database.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
      raise Error, "Unsafe restore database name: #{restore_database.inspect}"
    end
    raise Error, "Restore database must differ from source database" if restore_database == source_database
    return if restore_database.start_with?(restore_database_prefix)

    raise Error, "Restore database must begin with #{restore_database_prefix.inspect}"
  end

  def ensure_restore_database_absent!
    return unless database_exists?(restore_database)

    raise Error, "Refusing to overwrite existing database #{restore_database}"
  end

  def drop_created_restore_database
    run_psql("DROP DATABASE #{quote_identifier(restore_database)} WITH (FORCE);")
  end

  def create_restore_database
    run_psql("CREATE DATABASE #{quote_identifier(restore_database)};")
    @restore_database_created = true
  end

  def restore_backup
    stdout, stderr, status = Open3.capture3(
      postgres_connection.environment,
      "pg_restore",
      "--exit-on-error",
      "--no-owner",
      "--no-acl",
      *postgres_connection.arguments(database: restore_database),
      backup_path.to_s
    )

    verify_restore_database_exists!
    raise Error, "pg_restore failed: #{stderr.presence || stdout.presence || 'unknown error'}" unless status.success?
  end

  def compare_restored_database
    source_counts = row_counts_for(source_database)
    restored_counts = row_counts_for(restore_database)
    source_fingerprints = table_fingerprints_for(source_database)
    restored_fingerprints = table_fingerprints_for(restore_database)
    source_schema_checksum = schema_checksum_for(source_database)
    restored_schema_checksum = schema_checksum_for(restore_database)

    mismatches = source_counts.filter_map do |table_name, source_count|
      restored_count = restored_counts[table_name]
      next if restored_count == source_count

      {
        table_name: table_name,
        source_count: source_count,
        restored_count: restored_count
      }
    end

    {
      source_database: source_database,
      restore_database: restore_database,
      backup_path: backup_path.to_s,
      source_row_count_checksum: checksum(source_counts),
      restored_row_count_checksum: checksum(restored_counts),
      row_counts_match: mismatches.empty?,
      source_content_checksum: checksum(source_fingerprints),
      restored_content_checksum: checksum(restored_fingerprints),
      content_matches: source_fingerprints == restored_fingerprints,
      source_schema_checksum: source_schema_checksum,
      restored_schema_checksum: restored_schema_checksum,
      schema_matches: source_schema_checksum == restored_schema_checksum,
      mismatches: mismatches,
      verified_at: Time.current.iso8601
    }.tap do |result|
      raise Error, "Restored row counts do not match source database" unless result[:row_counts_match]
      raise Error, "Restored content fingerprints do not match source database" unless result[:content_matches]
      raise Error, "Restored schema does not match source database" unless result[:schema_matches]
    end
  end

  def row_counts_for(database)
    sql = <<~SQL.squish
      SELECT c.relname AS table_name
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relkind = 'r'
      ORDER BY c.relname
    SQL

    table_names = run_psql(sql, database: database).split("\n").reject(&:blank?)
    table_names.index_with do |table_name|
      run_psql("SELECT COUNT(*) FROM #{quote_identifier(table_name)};", database: database).to_i
    end
  end

  def checksum(row_counts)
    Digest::SHA256.hexdigest(JSON.generate(row_counts.sort.to_h))
  end

  def table_fingerprints_for(database)
    StorageAudit::CRITICAL_TABLES.index_with do |table_name|
      run_psql(<<~SQL.squish, database: database)
        SELECT COUNT(*)::text || ':' ||
          COALESCE(SUM(hashtextextended(row_to_json(records)::text, 0)::numeric), 0)::text
        FROM #{quote_identifier(table_name)} records;
      SQL
    end
  end

  def schema_checksum_for(database)
    sql = <<~SQL.squish
      SELECT object_definition
      FROM (
        SELECT 'column|' || table_name || '|' || column_name || '|' || data_type || '|' ||
          COALESCE(udt_name, '') || '|' || is_nullable || '|' || COALESCE(column_default, '') AS object_definition
        FROM information_schema.columns
        WHERE table_schema = 'public'
        UNION ALL
        SELECT 'index|' || tablename || '|' || indexname || '|' || indexdef
        FROM pg_indexes
        WHERE schemaname = 'public'
        UNION ALL
        SELECT 'constraint|' || c.relname || '|' || con.conname || '|' || pg_get_constraintdef(con.oid)
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
        UNION ALL
        SELECT 'migration|' || version
        FROM schema_migrations
      ) schema_objects
      ORDER BY object_definition;
    SQL

    Digest::SHA256.hexdigest(run_psql(sql, database: database))
  end

  def run_psql(sql, database: "postgres")
    command = [
      "psql",
      "--no-psqlrc",
      "--tuples-only",
      "--no-align",
      "--command=#{sql}"
    ]

    command.concat(postgres_connection.arguments(database: database))

    stdout, stderr, status = Open3.capture3(postgres_connection.environment, *command)
    raise Error, "psql failed: #{stderr.presence || stdout}" unless status.success?

    stdout.strip
  end

  def quote_identifier(identifier)
    %("#{identifier.gsub('"', '""')}")
  end

  def verify_restore_database_exists!
    raise Error, "Restore database #{restore_database} was not created" unless database_exists?(restore_database)
  end

  def database_exists?(database_name)
    result = run_psql("SELECT 1 FROM pg_database WHERE datname = #{quote_literal(database_name)};")
    result == "1"
  end

  def quote_literal(value)
    "'#{value.to_s.gsub("'", "''")}'"
  end

  def restore_database_created?
    @restore_database_created
  end
end
