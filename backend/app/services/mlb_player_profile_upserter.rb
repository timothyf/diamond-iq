class MlbPlayerProfileUpserter
  SOURCE_NAME = "MLB Stats API"

  def self.call(player:, person:, fetched_at: Time.current, position_payload: nil, seasons: [ nil ])
    new(
      player: player,
      person: person,
      fetched_at: fetched_at,
      position_payload: position_payload,
      seasons: seasons
    ).call
  end

  def initialize(player:, person:, fetched_at:, position_payload:, seasons:)
    @player = player
    @person = person
    @fetched_at = parse_time(fetched_at)
    @position_payload = position_payload || person["primaryPosition"]
    @seasons = Array(seasons).uniq
  end

  def call
    validate!
    update_player!
    profile, profile_created = upsert_profile!
    position, position_assignment_count = upsert_position!

    {
      profile: profile,
      profile_created: profile_created,
      position: position,
      position_assignment_count: position_assignment_count
    }
  end

  private

  attr_reader :player, :person, :fetched_at, :position_payload, :seasons

  def validate!
    raise ArgumentError, "Person payload must be a JSON object" unless person.is_a?(Hash)
    raise ArgumentError, "Fetched-at timestamp is required" if fetched_at.nil?

    person_mlb_id = Integer(person["id"], exception: false)
    raise ArgumentError, "Person payload is missing id" if person_mlb_id.nil?
    raise ArgumentError, "Person id #{person_mlb_id} does not match player MLB id #{player.mlb_id}" if person_mlb_id != player.mlb_id
  end

  def update_player!
    first_name = person["useName"].presence || person["firstName"].presence
    last_name = person["useLastName"].presence || person["lastName"].presence
    player.assign_attributes(first_name: first_name, last_name: last_name)
    player.save! if player.changed?
  end

  def upsert_profile!
    profile = player.profile || player.build_profile
    created = profile.new_record?
    profile.assign_attributes(
      birth_date: parse_date(person["birthDate"]),
      height_inches: parse_height(person["height"]),
      weight_pounds: parse_integer(person["weight"]),
      bats: normalized_hand(person.dig("batSide", "code"), allow_switch: true),
      throws: normalized_hand(person.dig("pitchHand", "code"), allow_switch: false),
      mlb_debut_date: parse_date(person["mlbDebutDate"]),
      headshot_id: player.mlb_id.to_s,
      source_name: SOURCE_NAME,
      last_synced_at: fetched_at,
      raw_data: person
    )
    profile.save!
    [ profile, created ]
  end

  def upsert_position!
    return [ nil, 0 ] if position_payload.blank?

    mlb_code = position_payload["code"].to_s.strip.upcase
    abbreviation = position_payload["abbreviation"].to_s.strip.upcase
    return [ nil, 0 ] if mlb_code.blank? || abbreviation.blank?

    position = Position.find_or_initialize_by(mlb_code: mlb_code)
    position.assign_attributes(
      abbreviation: abbreviation,
      name: position_payload["name"].presence || abbreviation,
      position_type: normalize_position_type(position_payload["type"]),
      sort_order: position.sort_order.presence || Position.maximum(:sort_order).to_i + 1
    )
    position.save!

    seasons.each do |season|
      player.player_positions.where(season: season, is_primary: true).where.not(position: position).update_all(
        is_primary: false,
        updated_at: fetched_at
      )
      assignment = player.player_positions.find_or_initialize_by(position: position, season: season)
      assignment.assign_attributes(is_primary: true, source_name: SOURCE_NAME, last_synced_at: fetched_at)
      assignment.save!
    end

    [ position, seasons.length ]
  end

  def normalize_position_type(value)
    normalized = value.to_s.downcase
    return "pitcher" if normalized.include?("pitcher")
    return "catcher" if normalized.include?("catcher")
    return "infielder" if normalized.include?("infielder")
    return "outfielder" if normalized.include?("outfielder")
    return "designated_hitter" if normalized.include?("designated")
    return "two_way" if normalized.include?("two-way") || normalized.include?("two way")

    "other"
  end

  def normalized_hand(value, allow_switch:)
    hand = value.to_s.strip.upcase
    allowed = allow_switch ? %w[L R S] : %w[L R]
    allowed.include?(hand) ? hand : nil
  end

  def parse_height(value)
    match = value.to_s.match(/\A\s*(\d+)'\s*(\d+)"\s*\z/)
    return if match.nil?

    (match[1].to_i * 12) + match[2].to_i
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_time(value)
    return value.in_time_zone if value.respond_to?(:in_time_zone)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_integer(value)
    Integer(value, exception: false)
  end
end
