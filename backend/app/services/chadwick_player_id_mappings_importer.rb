require "csv"
require "open3"
require "pathname"

class ChadwickPlayerIdMappingsImporter
  PEOPLE_FILES = ("0".."9").to_a.concat(("a".."f").to_a).map { |suffix| "chadwick-register/data/people-#{suffix}.csv" }.freeze
  BATCH_SIZE = 1_000
  UPSERT_INDEX = :index_player_id_mappings_on_mlb_id

  COLUMN_MAP = {
    chadwick_id: "key_person",
    chadwick_uuid: "key_uuid",
    retrosheet_id: "key_retro",
    baseball_reference_id: "key_bbref",
    baseball_reference_minors_id: "key_bbref_minors",
    fangraphs_id: "key_fangraphs",
    npb_id: "key_npb",
    pro_football_reference_id: "key_sr_nfl",
    basketball_reference_id: "key_sr_nba",
    hockey_reference_id: "key_sr_nhl",
    wikidata_id: "key_wikidata"
  }.freeze

  def self.call(zip_path:, imported_at: Time.current)
    new(zip_path: zip_path, imported_at: imported_at).call
  end

  def initialize(zip_path:, imported_at:)
    @zip_path = Pathname(zip_path)
    @imported_at = imported_at
  end

  def call
    return failure("Chadwick Register zip file was not found: #{zip_path}") unless zip_path.file?

    imported_count = 0
    skipped_count = 0
    batch = []

    PEOPLE_FILES.each do |entry|
      each_csv_row(entry) do |row|
        attributes = mapping_attributes(row)
        if attributes.nil?
          skipped_count += 1
          next
        end

        batch << attributes
        next unless batch.length >= BATCH_SIZE

        imported_count += upsert_batch(batch)
        batch.clear
      end
    end
    imported_count += upsert_batch(batch)

    {
      success: true,
      message: "Imported #{imported_count} Chadwick MLB player ID mappings",
      data: {
        imported_count: imported_count,
        skipped_count: skipped_count,
        source_name: PlayerIdMapping::SOURCE_NAME,
        zip_path: zip_path.to_s
      }
    }
  rescue CSV::MalformedCSVError => error
    failure("Failed to parse Chadwick Register CSV: #{error.message}")
  rescue StandardError => error
    failure("Failed to import Chadwick player ID mappings: #{error.message}")
  end

  private

  attr_reader :zip_path, :imported_at

  def each_csv_row(entry)
    Open3.popen3("unzip", "-p", zip_path.to_s, entry) do |stdin, stdout, stderr, wait_thread|
      stdin.close
      CSV.new(stdout, headers: true).each { |row| yield row }
      error = stderr.read
      raise "Could not read #{entry}: #{error.presence || 'unzip failed'}" unless wait_thread.value.success?
    end
  end

  def mapping_attributes(row)
    mlb_id = Integer(row["key_mlbam"], exception: false)
    return if mlb_id.nil? || row["key_person"].blank? || row["key_uuid"].blank?

    now = imported_at
    {
      mlb_id: mlb_id,
      **COLUMN_MAP.to_h { |attribute, column| [ attribute, row[column].presence ] },
      source_name: PlayerIdMapping::SOURCE_NAME,
      imported_at: now,
      created_at: now,
      updated_at: now
    }
  end

  def upsert_batch(batch)
    return 0 if batch.empty?

    PlayerIdMapping.upsert_all(batch, unique_by: UPSERT_INDEX)
    batch.length
  end

  def failure(message)
    { success: false, message: message, data: { errors: [ message ] } }
  end
end
