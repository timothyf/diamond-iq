require "csv"

class PlayerSeasonStatsTeamVerifier
  PLAYER_ID_FIELDS = %w[playerId player_id playerid mlb_id id].freeze
  TEAM_ID_FIELDS = %w[teamId team_id teamid].freeze
  TEAM_NAME_FIELDS = %w[teamName team_name teamname].freeze
  TEAM_ABBREVIATION_FIELDS = %w[teamAbbrev team_abbrev teamabbrev abbreviation abbrev].freeze
  TEAM_SHORT_NAME_FIELDS = %w[teamShortName team_short_name teamshortname short_name shortname].freeze
  SEASON_FIELDS = %w[season year source_season sourceSeason].freeze
  STAT_GROUP_FIELDS = %w[stat_type statType].freeze
  CATEGORY_MAP = {
    "batter" => "batting",
    "batting" => "batting",
    "hitting" => "batting",
    "pitcher" => "pitching",
    "pitching" => "pitching"
  }.freeze
  MAX_SAMPLE_COUNT = 10

  def self.call(category:, start_year:, end_year:, fix: false, downloader: PlayerStatsDownloader)
    new(downloader: downloader).call(category: category, start_year: start_year, end_year: end_year, fix: fix)
  end

  def initialize(downloader: PlayerStatsDownloader)
    @downloader = downloader
  end

  def call(category:, start_year:, end_year:, fix: false)
    normalized_category = normalize_category(category)
    return failure("Category must be batting or pitching") if normalized_category.blank?

    download_result = downloader.call(category: normalized_category, start_year: start_year, end_year: end_year)
    return download_result unless download_result[:success]

    verify_source_rows(
      CSV.parse(download_result.dig(:data, :csv_data), headers: true),
      category: normalized_category,
      fix: cast_boolean(fix)
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse MLB verification CSV: #{e.message}")
  end

  private

  attr_reader :downloader

  def verify_source_rows(csv, category:, fix:)
    summary = {
      checked_groups: 0,
      missing_player_groups: 0,
      missing_stat_groups: 0,
      mismatched_groups: 0,
      mismatched_rows: 0,
      updated_rows: 0,
      samples: []
    }

    csv.each do |row|
      source_row = build_source_row(row.to_h)
      next if source_row.nil? || source_row[:category] != category

      player = Player.find_by(mlb_id: source_row[:player_mlb_id])
      if player.nil?
        summary[:missing_player_groups] += 1
        next
      end

      scope = PlayerSeasonStat
        .joins(:stat_type)
        .where(player: player, season: source_row[:season], stat_types: { category: category })

      if scope.empty?
        summary[:missing_stat_groups] += 1
        next
      end

      summary[:checked_groups] += 1
      stored_team_ids = scope.distinct.pluck(:team_id)
      stored_team_mlb_ids = Team.where(id: stored_team_ids.compact).pluck(:id, :mlb_id).to_h
      next if stored_team_ids.one? && stored_team_mlb_ids[stored_team_ids.first] == source_row[:team_attributes][:mlb_id]

      mismatched_rows = scope.count
      summary[:mismatched_groups] += 1
      summary[:mismatched_rows] += mismatched_rows
      add_sample(summary, player: player, source_row: source_row, stored_team_ids: stored_team_ids, stored_team_mlb_ids: stored_team_mlb_ids, row_count: mismatched_rows)

      summary[:updated_rows] += repair_scope(scope, source_row[:team_attributes]) if fix
    end

    success("Verified player season team ids", summary.merge(fix: fix))
  end

  def repair_scope(scope, team_attributes)
    team = Team.find_or_initialize_by(mlb_id: team_attributes[:mlb_id])
    team.assign_attributes(team_attributes)
    team.save!

    scope.update_all(team_id: team.id, updated_at: Time.current)
  end

  def add_sample(summary, player:, source_row:, stored_team_ids:, stored_team_mlb_ids:, row_count:)
    return if summary[:samples].length >= MAX_SAMPLE_COUNT

    summary[:samples] << {
      player: "#{player.first_name} #{player.last_name}",
      player_mlb_id: player.mlb_id,
      season: source_row[:season],
      expected_team: source_row[:team_attributes][:abbreviation],
      expected_team_mlb_id: source_row[:team_attributes][:mlb_id],
      stored_team_ids: stored_team_ids,
      stored_team_mlb_ids: stored_team_ids.map { |team_id| stored_team_mlb_ids[team_id] },
      row_count: row_count
    }
  end

  def build_source_row(row_hash)
    normalized_row = normalize_row(row_hash)
    key_map = normalized_row.keys.index_by(&:downcase)
    player_mlb_id = parse_integer(fetch_value(normalized_row, key_map, PLAYER_ID_FIELDS))
    season = parse_integer(fetch_value(normalized_row, key_map, SEASON_FIELDS))
    category = normalize_category(fetch_value(normalized_row, key_map, STAT_GROUP_FIELDS))
    team_attributes = build_team_attributes(normalized_row, key_map)

    return nil if player_mlb_id.nil? || season.nil? || category.blank? || team_attributes.values.any?(&:blank?)

    {
      player_mlb_id: player_mlb_id,
      season: season,
      category: category,
      team_attributes: team_attributes
    }
  end

  def build_team_attributes(normalized_row, key_map)
    team_abbreviation = fetch_value(normalized_row, key_map, TEAM_ABBREVIATION_FIELDS)
    full_team_name = fetch_value(normalized_row, key_map, TEAM_NAME_FIELDS)
    short_name = fetch_value(normalized_row, key_map, TEAM_SHORT_NAME_FIELDS).presence || full_team_name
    team_mlb_id = parse_integer(fetch_value(normalized_row, key_map, TEAM_ID_FIELDS))

    {
      mlb_id: team_mlb_id,
      name: full_team_name,
      abbreviation: team_abbreviation,
      team_name: short_name,
      location_name: location_name(full_team_name, short_name),
      short_name: short_name,
      team_code: team_abbreviation.to_s.downcase,
      file_code: team_abbreviation.to_s.downcase
    }
  end

  def location_name(full_team_name, short_name)
    if full_team_name.present? && short_name.present? && full_team_name.end_with?(short_name) && full_team_name != short_name
      full_team_name.delete_suffix(short_name).strip.presence || full_team_name
    else
      full_team_name
    end
  end

  def normalize_row(row_hash)
    row_hash.to_h.transform_keys { |key| key.to_s.strip.delete_prefix("\uFEFF") }
  end

  def fetch_value(row, key_map, keys)
    keys.each do |key|
      mapped_key = key_map[key.downcase]
      value = row[mapped_key] if mapped_key
      return value.to_s.strip if value.present?
    end

    nil
  end

  def parse_integer(value)
    Integer(value.to_s, exception: false)
  end

  def normalize_category(value)
    CATEGORY_MAP[value.to_s.strip.downcase]
  end

  def cast_boolean(value)
    %w[1 true t yes y on].include?(value.to_s.strip.downcase)
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
