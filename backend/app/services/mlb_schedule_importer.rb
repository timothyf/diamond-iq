class MlbScheduleImporter
  SOURCE_NAME = "MLB Stats API"

  class ImportError < StandardError
    attr_reader :errors

    def initialize(message, errors = [])
      super(message)
      @errors = errors
    end
  end

  attr_reader :payload, :start_date, :end_date, :game_types, :sport_id, :source_url, :fetched_at

  def self.call(payload:, start_date:, end_date:, game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES, sport_id: 1, source_url: nil, fetched_at: Time.current)
    new(
      payload: payload,
      start_date: start_date,
      end_date: end_date,
      game_types: game_types,
      sport_id: sport_id,
      source_url: source_url,
      fetched_at: fetched_at
    ).call
  end

  def initialize(payload:, start_date:, end_date:, game_types: MlbScheduleDownloader::DEFAULT_GAME_TYPES, sport_id: 1, source_url: nil, fetched_at: Time.current)
    @payload = payload
    @start_date = parse_date(start_date)
    @end_date = parse_date(end_date)
    @game_types = parse_game_types(game_types)
    @sport_id = Integer(sport_id, exception: false)
    @source_url = source_url.presence
    @fetched_at = parse_time(fetched_at)
  end

  def call
    validation_errors = input_errors
    return failure("MLB schedule import validation failed", validation_errors) if validation_errors.any?

    games = extract_games
    counts = persist(games)

    success(
      "Synchronized #{counts[:game_count]} MLB games",
      counts.merge(
        source_key: source_key,
        start_date: start_date.iso8601,
        end_date: end_date.iso8601,
        game_types: game_types
      )
    )
  rescue ImportError => e
    failure(e.message, e.errors)
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import MLB schedule: #{e.message}")
  end

  private

  def input_errors
    errors = []
    errors << "Payload must be a JSON object" unless payload.is_a?(Hash)
    errors << "Start date is required" if start_date.nil?
    errors << "End date is required" if end_date.nil?
    errors << "End date must be greater than or equal to start date" if start_date && end_date && end_date < start_date
    errors << "At least one game type is required" if game_types.empty?
    errors << "Sport id must be a positive integer" if sport_id.nil? || sport_id < 1
    errors << "Fetched-at timestamp is required" if fetched_at.nil?
    errors
  end

  def extract_games
    Array(payload["dates"]).flat_map { |date_entry| Array(date_entry["games"]) }
  end

  def persist(games)
    counts = {
      game_count: 0,
      created_game_count: 0,
      updated_game_count: 0,
      created_team_count: 0,
      created_player_count: 0
    }

    Schedule.transaction do
      schedule = Schedule.find_or_initialize_by(source_key: source_key)
      schedule.assign_attributes(schedule_attributes)
      schedule.save!

      games.index_by { |game| game["gamePk"].to_s }.each_value do |game_payload|
        persist_game!(schedule, game_payload, counts)
      end
    rescue ActiveRecord::RecordInvalid => e
      record_errors = e.record.errors.full_messages
      raise ActiveRecord::Rollback if record_errors.empty?

      raise ImportError.new("MLB schedule import validation failed", record_errors)
    end

    counts
  end

  def persist_game!(schedule, game_payload, counts)
    game_mlb_id = parse_integer(game_payload["gamePk"])
    raise ImportError.new("MLB schedule import validation failed", [ "Game is missing gamePk" ]) if game_mlb_id.nil?

    home_payload = game_payload.dig("teams", "home", "team")
    away_payload = game_payload.dig("teams", "away", "team")
    home_team, home_created = resolve_team!(home_payload)
    away_team, away_created = resolve_team!(away_payload)
    counts[:created_team_count] += 1 if home_created
    counts[:created_team_count] += 1 if away_created

    home_pitcher, home_pitcher_created = resolve_probable_pitcher(game_payload.dig("teams", "home", "probablePitcher"), home_team)
    away_pitcher, away_pitcher_created = resolve_probable_pitcher(game_payload.dig("teams", "away", "probablePitcher"), away_team)
    counts[:created_player_count] += 1 if home_pitcher_created
    counts[:created_player_count] += 1 if away_pitcher_created

    game = Game.find_or_initialize_by(mlb_id: game_mlb_id)
    created = game.new_record?
    game.assign_attributes(
      schedule: schedule,
      official_date: parse_date(game_payload["officialDate"]),
      scheduled_at: parse_time(game_payload["gameDate"]),
      game_type: game_payload["gameType"],
      status: normalized_status(game_payload["status"]),
      detailed_status: game_payload.dig("status", "detailedState"),
      home_team: home_team,
      away_team: away_team,
      home_probable_pitcher: home_pitcher,
      away_probable_pitcher: away_pitcher,
      venue_name: game_payload.dig("venue", "name"),
      game_number: parse_integer(game_payload["gameNumber"]),
      doubleheader: game_payload["doubleHeader"],
      home_score: parse_integer(game_payload.dig("teams", "home", "score")),
      away_score: parse_integer(game_payload.dig("teams", "away", "score")),
      source_name: SOURCE_NAME,
      source_url: game_source_url(game_payload),
      last_synced_at: fetched_at,
      raw_data: game_payload
    )
    game.save!

    counts[:game_count] += 1
    counts[created ? :created_game_count : :updated_game_count] += 1
  end

  def resolve_team!(team_payload)
    team_mlb_id = parse_integer(team_payload&.fetch("id", nil))
    raise ImportError.new("MLB schedule import validation failed", [ "Game team is missing an MLB id" ]) if team_mlb_id.nil?

    team = Team.find_or_initialize_by(mlb_id: team_mlb_id)
    created = team.new_record?
    team.assign_attributes(
      name: team_payload["name"].presence || team_payload["teamName"],
      abbreviation: team_payload["abbreviation"],
      team_name: team_payload["teamName"].presence || team_payload["name"],
      location_name: team_payload["locationName"].presence || team_payload["name"],
      short_name: team_payload["shortName"].presence || team_payload["teamName"].presence || team_payload["name"],
      team_code: team_payload["teamCode"].presence || team_payload["abbreviation"].to_s.downcase,
      file_code: team_payload["fileCode"].presence || team_payload["abbreviation"].to_s.downcase
    )
    team.save!
    [ team, created ]
  end

  def resolve_probable_pitcher(pitcher_payload, team)
    pitcher_mlb_id = parse_integer(pitcher_payload&.fetch("id", nil))
    return [ nil, false ] if pitcher_mlb_id.nil?

    player = Player.find_or_initialize_by(mlb_id: pitcher_mlb_id)
    created = player.new_record?

    if created
      first_name, last_name = split_name(pitcher_payload["fullName"])
      return [ nil, false ] if first_name.blank? || last_name.blank?

      player.assign_attributes(first_name: first_name, last_name: last_name, team: team)
      player.save!
    end

    [ player, created ]
  end

  def split_name(full_name)
    parts = full_name.to_s.strip.split
    return [ nil, nil ] if parts.length < 2

    [ parts[0...-1].join(" "), parts.last ]
  end

  def schedule_attributes
    {
      season: start_date.year,
      schedule_type: game_types.join(","),
      start_date: start_date,
      end_date: end_date,
      source_name: SOURCE_NAME,
      source_url: source_url,
      last_synced_at: fetched_at,
      raw_data: payload
    }
  end

  def source_key
    "mlb:schedule:#{sport_id}:#{start_date.iso8601}:#{end_date.iso8601}:#{game_types.join(',')}"
  end

  def normalized_status(status_payload)
    detailed_status = status_payload&.fetch("detailedState", nil).to_s
    return "postponed" if detailed_status.downcase.include?("postponed")

    status_payload&.fetch("abstractGameState", nil).to_s.parameterize.presence || "unknown"
  end

  def game_source_url(game_payload)
    link = game_payload["link"].to_s
    return source_url if link.blank?

    "https://statsapi.mlb.com#{link}"
  end

  def parse_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_time(value)
    return if value.blank?
    return value.in_time_zone if value.respond_to?(:in_time_zone)

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_integer(value)
    Integer(value, exception: false)
  end

  def parse_game_types(value)
    Array(value.to_s.split(",")).map { |item| item.strip.upcase }.reject(&:blank?).uniq.sort
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [])
    { success: false, message: message, data: { errors: errors } }
  end
end
