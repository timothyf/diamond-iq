require "csv"

class PlayerStatsImporter
  PLAYER_ID_FIELDS = %w[player_id playerid id].freeze
  FIRST_NAME_FIELDS = %w[first_name firstname].freeze
  LAST_NAME_FIELDS = %w[last_name lastname].freeze
  FULL_NAME_FIELDS = %w[name full_name fullname].freeze

  TEAM_NAME_FIELDS = %w[team_name teamname].freeze
  LOCATION_NAME_FIELDS = %w[location_name locationname].freeze
  TEAM_DISPLAY_NAME_FIELDS = %w[team_display_name team_display full_team_name].freeze
  ABBREVIATION_FIELDS = %w[abbreviation abbrev].freeze
  SHORT_NAME_FIELDS = %w[short_name shortname].freeze
  TEAM_CODE_FIELDS = %w[team_code teamcode].freeze
  FILE_CODE_FIELDS = %w[file_code filecode].freeze

  RESERVED_COLUMNS = (
    PLAYER_ID_FIELDS +
    FIRST_NAME_FIELDS +
    LAST_NAME_FIELDS +
    FULL_NAME_FIELDS +
    TEAM_NAME_FIELDS +
    LOCATION_NAME_FIELDS +
    TEAM_DISPLAY_NAME_FIELDS +
    ABBREVIATION_FIELDS +
    SHORT_NAME_FIELDS +
    TEAM_CODE_FIELDS +
    FILE_CODE_FIELDS
  ).freeze

  def self.call(csv_data: nil, file_path: nil, source_name: nil, required_stat_columns: [])
    new(
      csv_data: csv_data,
      file_path: file_path,
      source_name: source_name,
      required_stat_columns: required_stat_columns
    ).call
  end

  def initialize(csv_data: nil, file_path: nil, source_name: nil, required_stat_columns: [])
    @csv_data = csv_data
    @file_path = file_path
    @source_name = source_name
    @required_stat_columns = Array(required_stat_columns).map { |column| column.to_s.strip }.reject(&:blank?)
    @errors = []
  end

  def call
    return failure("CSV data or file path is required") if csv_source.blank?
    return failure("Source name is required") if resolved_source_name.blank?

    csv = CSV.parse(csv_source, headers: true)
    return failure("CSV must include headers") if csv.headers.blank?

    missing_columns = missing_required_stat_columns(csv.headers)
    return failure("Missing required stat columns: #{missing_columns.join(', ')}") if missing_columns.any?

    import_rows = build_import_rows(csv)
    return failure("No valid player stat rows found in CSV") if import_rows.empty?

    persisted = persist_rows(import_rows)
    success(
      "Imported #{persisted[:imported_count]} player stat rows",
      persisted.merge(
        skipped_count: errors.length,
        duplicate_count: @duplicate_count || 0,
        errors: errors
      )
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse CSV: #{e.message}")
  rescue Errno::ENOENT => e
    failure("Failed to read CSV file: #{e.message}")
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import player stats: #{e.message}")
  end

  private

  attr_reader :csv_data, :file_path, :source_name, :required_stat_columns, :errors

  def csv_source
    @csv_source ||= if csv_data.present?
      csv_data
    elsif file_path.present?
      File.read(file_path)
    end
  end

  def resolved_source_name
    @resolved_source_name ||= source_name.presence || file_path.to_s.presence
  end

  def missing_required_stat_columns(headers)
    normalized_headers = headers.compact.map { |header| header.to_s.strip.downcase }

    required_stat_columns.reject do |column|
      normalized_headers.include?(column.downcase)
    end
  end

  def build_import_rows(csv)
    @duplicate_count = 0
    rows_by_player_id = {}

    csv.each_with_index do |row, index|
      source_row_number = index + 2
      import_row = build_import_row(row, source_row_number)
      next if import_row.nil?

      if rows_by_player_id.key?(import_row[:player_id])
        @duplicate_count += 1
      end

      rows_by_player_id[import_row[:player_id]] = import_row
    end

    rows_by_player_id.values
  end

  def build_import_row(row, source_row_number)
    normalized_row = normalize_row(row.to_h)

    player_id = fetch_value(normalized_row, PLAYER_ID_FIELDS)
    first_name = fetch_value(normalized_row, FIRST_NAME_FIELDS)
    last_name = fetch_value(normalized_row, LAST_NAME_FIELDS)

    if first_name.blank? || last_name.blank?
      derived_first_name, derived_last_name = split_name(fetch_value(normalized_row, FULL_NAME_FIELDS))
      first_name ||= derived_first_name
      last_name ||= derived_last_name
    end

    team_attributes = build_team_attributes(normalized_row)
    stats_data = extract_stats_data(normalized_row)

    missing_identity_fields = []
    missing_identity_fields << "player_id" if player_id.blank?
    missing_identity_fields << "first_name" if first_name.blank?
    missing_identity_fields << "last_name" if last_name.blank?

    if missing_identity_fields.any?
      errors << row_error(source_row_number, "Missing required player fields: #{missing_identity_fields.join(', ')}")
      return nil
    end

    if team_attributes.values.any?(&:blank?)
      missing_team_fields = team_attributes.select { |_key, value| value.blank? }.keys
      errors << row_error(source_row_number, "Missing required team fields: #{missing_team_fields.join(', ')}")
      return nil
    end

    if stats_data.blank?
      errors << row_error(source_row_number, "Missing statistical columns for player #{player_id}")
      return nil
    end

    {
      player_id: player_id,
      first_name: first_name,
      last_name: last_name,
      row_number: source_row_number,
      team_attributes: team_attributes,
      stats_data: stats_data
    }
  end

  def build_team_attributes(normalized_row)
    team_name = fetch_value(normalized_row, TEAM_NAME_FIELDS)
    location_name = fetch_value(normalized_row, LOCATION_NAME_FIELDS)
    abbreviation = fetch_value(normalized_row, ABBREVIATION_FIELDS)
    short_name = fetch_value(normalized_row, SHORT_NAME_FIELDS) || team_name
    team_code = fetch_value(normalized_row, TEAM_CODE_FIELDS) || abbreviation&.downcase
    file_code = fetch_value(normalized_row, FILE_CODE_FIELDS) || team_code
    display_name = fetch_value(normalized_row, TEAM_DISPLAY_NAME_FIELDS)

    derived_name = if display_name.present? && display_name != team_name
      display_name
    elsif location_name.present? && team_name.present?
      "#{location_name} #{team_name}"
    else
      team_name
    end

    {
      name: derived_name,
      abbreviation: abbreviation,
      team_name: team_name,
      location_name: location_name,
      short_name: short_name,
      team_code: team_code,
      file_code: file_code
    }
  end

  def extract_stats_data(normalized_row)
    normalized_row.each_with_object({}) do |(key, value), stats|
      next if reserved_column?(key)
      next if value.blank?

      stats[key] = value
    end
  end

  def persist_rows(import_rows)
    timestamp = Time.current
    stat_records = []
    created_player_count = 0
    created_team_count = 0

    PlayerStat.transaction do
      PlayerStat.where(source_url: resolved_source_name).delete_all

      import_rows.each do |import_row|
        team = Team.find_or_initialize_by(team_code: import_row[:team_attributes][:team_code])
        created_team_count += 1 if team.new_record?
        team.assign_attributes(import_row[:team_attributes])
        team.save!

        player = Player.find_or_initialize_by(
          first_name: import_row[:first_name],
          last_name: import_row[:last_name],
          team: team
        )
        created_player_count += 1 if player.new_record?
        player.save!

        stat_records << {
          player_id: import_row[:player_id],
          source_url: resolved_source_name,
          row_number: import_row[:row_number],
          stats_data: import_row[:stats_data],
          created_at: timestamp,
          updated_at: timestamp
        }
      end

      PlayerStat.insert_all!(stat_records)
    end

    {
      imported_count: stat_records.length,
      created_player_count: created_player_count,
      created_team_count: created_team_count
    }
  end

  def normalize_row(row_hash)
    row_hash.each_with_object({}) do |(key, value), normalized|
      next if key.nil?

      clean_key = key.to_s.strip
      next if clean_key.empty?

      normalized[clean_key] = value.is_a?(String) ? value.strip : value
    end
  end

  def fetch_value(normalized_row, aliases)
    aliases.each do |field_name|
      matched_key = normalized_row.keys.find { |key| key.casecmp?(field_name) }
      return normalized_row[matched_key] if matched_key
    end

    nil
  end

  def split_name(full_name)
    return [nil, nil] if full_name.blank?

    parts = full_name.to_s.split
    return [parts.first, nil] if parts.one?

    [parts[0..-2].join(" "), parts.last]
  end

  def reserved_column?(column_name)
    RESERVED_COLUMNS.any? { |reserved| reserved.casecmp?(column_name) }
  end

  def row_error(source_row_number, message)
    {
      row_number: source_row_number,
      error: message
    }
  end

  def success(message, data = nil)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: { errors: errors } }
  end
end
