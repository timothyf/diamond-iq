require "rails_helper"

RSpec.describe StorageAudit do
  it "returns database, table, row-count, JSON, and readiness metadata" do
    report = described_class.call

    expect(report[:database]).to eq(ActiveRecord::Base.connection.current_database)
    expect(report[:database_size_bytes]).to be >= 0
    expect(report[:tables]).not_to be_empty
    expect(report[:row_counts]).not_to be_empty
    expect(report[:json_columns]).not_to be_empty
    expect(report[:integrity_checksum]).to match(/\A[0-9a-f]{64}\z/)
    expect(report[:row_count_checksum]).to match(/\A[0-9a-f]{64}\z/)
    expect(report[:critical_table_fingerprints].keys).to match_array(described_class::CRITICAL_TABLES)
    expect(report.dig(:archival_json_columns, :columns).length).to eq(described_class::ARCHIVAL_JSON_COLUMNS.length)
    expect(report[:critical_row_counts].keys).to include("players", "teams")
    expect(report[:rewrite_readiness]).to include(:ready_for_table_rewrite)
  end

  it "computes a stable row-count checksum" do
    row_counts = { "players" => 2, "teams" => 1 }
    audit = described_class.allocate

    checksum_one = audit.send(:row_count_checksum, row_counts)
    checksum_two = audit.send(:row_count_checksum, row_counts.sort.reverse.to_h)

    expect(checksum_one).to eq(checksum_two)
  end

  it "reports archival columns that have already been removed as absent" do
    audit = described_class.allocate
    allow(audit).to receive(:number_to_human_size).and_return("0 Bytes")

    summary = audit.send(:summarize_archival_json, [])

    expect(summary[:total_bytes]).to eq(0)
    expect(summary[:columns]).to all(include(present: false, payload_bytes: 0))
  end
end

RSpec.describe StorageBackup do
  it "creates a backup file with checksum metadata" do
    result = described_class.call(output_path: Rails.root.join("tmp/storage_baselines/spec_backup.dump"))

    expect(File).to exist(result[:backup_path])
    expect(result[:backup_bytes]).to be_positive
    expect(result[:backup_sha256]).to match(/\A[0-9a-f]{64}\z/)
    expect(result[:archive_verified]).to be(true)
  ensure
    FileUtils.rm_f(Rails.root.join("tmp/storage_baselines/spec_backup.dump"))
  end
end

RSpec.describe StorageRestoreTest do
  it "verifies row counts after restoring a backup" do
    backup = StorageBackup.call(output_path: Rails.root.join("tmp/storage_baselines/spec_restore_backup.dump"))
    result = described_class.call(backup_path: backup[:backup_path])

    expect(result[:row_counts_match]).to be(true)
    expect(result[:content_matches]).to be(true)
    expect(result[:schema_matches]).to be(true)
    expect(result[:source_row_count_checksum]).to eq(result[:restored_row_count_checksum])
    expect(result[:source_content_checksum]).to eq(result[:restored_content_checksum])
    expect(result[:source_schema_checksum]).to eq(result[:restored_schema_checksum])
  ensure
    FileUtils.rm_f(Rails.root.join("tmp/storage_baselines/spec_restore_backup.dump"))
  end


  it "refuses to use the source database as the restore target" do
    backup_path = Rails.root.join("tmp/storage_baselines/does_not_need_to_exist.dump")

    expect do
      described_class.call(
        backup_path: backup_path,
        restore_database: ActiveRecord::Base.connection_db_config.database
      )
    end.to raise_error(StorageRestoreTest::Error, /must differ from source/)
  end

  it "refuses to overwrite an existing restore database" do
    service = described_class.new(
      backup_path: Rails.root.join("tmp/storage_baselines/does_not_need_to_exist.dump"),
      source_database: "backend_test",
      restore_database: "backend_test_storage_restore_test_existing",
      postgres_connection: StoragePostgresConnection.new
    )
    allow(service).to receive(:database_exists?).and_return(true)

    expect { service.send(:ensure_restore_database_absent!) }
      .to raise_error(StorageRestoreTest::Error, /Refusing to overwrite/)
  end

  it "rejects a partial restore whenever pg_restore exits unsuccessfully" do
    service = described_class.new(
      backup_path: Rails.root.join("tmp/storage_baselines/partial_restore.dump"),
      source_database: "backend_test",
      restore_database: "backend_test_storage_restore_test_partial",
      postgres_connection: StoragePostgresConnection.new
    )
    failed_status = instance_double(Process::Status, success?: false)
    allow(Open3).to receive(:capture3).and_return([ "", "restore failed after creating tables", failed_status ])
    allow(service).to receive(:verify_restore_database_exists!)

    expect { service.send(:restore_backup) }
      .to raise_error(StorageRestoreTest::Error, /pg_restore failed: restore failed after creating tables/)
  end

  it "generates unique restore database names with the required safe prefix" do
    allow(SecureRandom).to receive(:hex).and_return("deadbeef", "cafebabe")

    first = described_class.new(
      backup_path: Rails.root.join("tmp/storage_baselines/first.dump"),
      source_database: "backend-test",
      restore_database: nil,
      postgres_connection: StoragePostgresConnection.new
    )
    second = described_class.new(
      backup_path: Rails.root.join("tmp/storage_baselines/second.dump"),
      source_database: "backend-test",
      restore_database: nil,
      postgres_connection: StoragePostgresConnection.new
    )
    first_name = first.send(:restore_database)
    second_name = second.send(:restore_database)

    expect(first_name).to match(/\Abackend_test_storage_restore_test_#{Process.pid}_deadbeef\z/)
    expect(second_name).to match(/\Abackend_test_storage_restore_test_#{Process.pid}_cafebabe\z/)
    expect(first_name).not_to eq(second_name)
    expect { first.send(:validate_restore_target!) }.not_to raise_error
    expect { second.send(:validate_restore_target!) }.not_to raise_error
  end
end


RSpec.describe StoragePostgresConnection do
  it "passes Rails connection settings to PostgreSQL command-line tools without exposing the password" do
    db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
      "test",
      "primary",
      adapter: "postgresql",
      database: "diamond_iq",
      host: "db.example.test",
      port: 5544,
      username: "diamond",
      password: "secret",
      sslmode: "require"
    )
    connection = described_class.new(db_config: db_config)

    expect(connection.arguments).to contain_exactly(
      "--host=db.example.test",
      "--port=5544",
      "--username=diamond",
      "--dbname=diamond_iq"
    )
    expect(connection.environment).to include("PGPASSWORD" => "secret", "PGSSLMODE" => "require")
    expect(connection.arguments.join(" ")).not_to include("secret")
  end
end
