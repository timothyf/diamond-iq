class MlbRosterImporter
  SOURCE_NAME = "MLB Stats API"

  class ImportError < StandardError
    attr_reader :errors

    def initialize(message, errors = [])
      super(message)
      @errors = errors
    end
  end

  attr_reader :payload, :team_mlb_id, :season, :roster_type, :as_of, :source_url, :fetched_at

  def self.call(payload:, team_mlb_id:, season:, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current, source_url: nil, fetched_at: Time.current)
    new(
      payload: payload,
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of,
      source_url: source_url,
      fetched_at: fetched_at
    ).call
  end

  def initialize(payload:, team_mlb_id:, season:, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current, source_url: nil, fetched_at: Time.current)
    @payload = payload
    @team_mlb_id = Integer(team_mlb_id, exception: false)
    @season = Integer(season, exception: false)
    @roster_type = roster_type.to_s.strip.presence
    @as_of = parse_date(as_of)
    @source_url = source_url.presence
    @fetched_at = parse_time(fetched_at)
  end

  def call
    errors = input_errors
    return failure("MLB roster import validation failed", errors) if errors.any?

    team = Team.find_by(mlb_id: team_mlb_id)
    return failure("MLB roster import validation failed", [ "Team with MLB id #{team_mlb_id} does not exist" ]) if team.nil?

    roster = team.rosters.find_by(season: season)
    if roster&.snapshot_on.present? && roster.snapshot_on > as_of
      return failure("MLB roster import validation failed", [ "Cannot synchronize #{as_of} before existing snapshot #{roster.snapshot_on}" ])
    end

    summary = persist(team)
    success("Synchronized #{summary[:membership_count]} MLB roster memberships", summary)
  rescue ImportError => e
    failure(e.message, e.errors)
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import MLB roster: #{e.message}")
  end

  private

  def input_errors
    errors = []
    errors << "Payload must be a JSON object" unless payload.is_a?(Hash)
    errors << "Payload must include a roster array" unless payload.is_a?(Hash) && payload["roster"].is_a?(Array)
    errors << "Team MLB id must be a positive integer" if team_mlb_id.nil? || team_mlb_id < 1
    errors << "Season must be greater than 1800" if season.nil? || season <= 1800
    errors << "Roster type is required" if roster_type.blank?
    errors << "As-of date is required" if as_of.nil?
    errors << "Fetched-at timestamp is required" if fetched_at.nil?
    errors
  end

  def persist(team)
    summary = {
      membership_count: 0,
      created_player_count: 0,
      created_profile_count: 0,
      created_membership_count: 0,
      updated_membership_count: 0,
      closed_membership_count: 0,
      position_assignment_count: 0,
      duplicate_entry_count: duplicate_entry_count
    }

    TeamMembership.transaction do
      players = entries_by_player_id.values.map do |entry|
        sync_entry!(team, entry, summary)
      end

      close_missing_memberships!(team, players.map(&:id), summary)
      refresh_on = as_of < Date.current ? Date.current : as_of
      players.each { |player| player.refresh_current_team!(on: refresh_on) }

      roster = team.rosters.find_or_initialize_by(season: season)
      if roster.new_record?
        roster.assign_attributes(
          roster_type: roster_type,
          snapshot_on: as_of,
          source_name: SOURCE_NAME,
          last_synced_at: fetched_at
        )
        roster.save!
      end
      roster.rebuild_from_memberships!(
        on: as_of,
        roster_type: roster_type,
        source_name: SOURCE_NAME,
        last_synced_at: fetched_at,
        raw_data: payload,
        player_ids: players.map(&:id)
      )
    end

    summary
  rescue ActiveRecord::RecordInvalid => e
    raise ImportError.new("MLB roster import validation failed", e.record.errors.full_messages)
  end

  def sync_entry!(team, entry, summary)
    person = entry["person"]
    person_mlb_id = parse_integer(person&.fetch("id", nil))
    raise ImportError.new("MLB roster import validation failed", [ "Roster entry is missing person.id" ]) if person_mlb_id.nil?

    player = Player.find_or_initialize_by(mlb_id: person_mlb_id)
    player_created = player.new_record?
    player.assign_attributes(
      first_name: person["useName"].presence || person["firstName"],
      last_name: person["useLastName"].presence || person["lastName"],
      team: team
    )
    player.save!
    summary[:created_player_count] += 1 if player_created

    profile_result = MlbPlayerProfileUpserter.call(
      player: player,
      person: person_with_preserved_profile_history(player, person),
      fetched_at: fetched_at,
      position_payload: entry["position"] || person["primaryPosition"],
      seasons: [ nil, season ]
    )
    summary[:created_profile_count] += 1 if profile_result[:profile_created]
    summary[:position_assignment_count] += profile_result[:position_assignment_count]
    position = profile_result[:position]
    sync_membership!(player, team, entry, position, summary)
    summary[:membership_count] += 1
    player
  end

  def person_with_preserved_profile_history(player, person)
    preserved_history = player.profile&.raw_data.to_h.slice("awards", "drafts", "draftYear") || {}
    preserved_history.merge(person)
  end

  def sync_membership!(player, team, entry, position, summary)
    status_payload = entry["status"] || {}
    normalized_status = MlbRosterStatus.normalize(
      code: status_payload["code"],
      description: status_payload["description"]
    )
    close_other_team_memberships!(player, team, summary)
    active_memberships = player.team_memberships
      .where(team: team, source_name: SOURCE_NAME)
      .active_on(as_of)
      .to_a
    membership = active_memberships.find { |record| record.roster_status == normalized_status }

    active_memberships.reject { |record| record == membership }.each do |record|
      close_membership!(record)
      summary[:closed_membership_count] += 1
    end

    membership ||= player.team_memberships.new(
      team: team,
      starts_on: as_of,
      roster_status: normalized_status,
      source_name: SOURCE_NAME,
      last_synced_at: fetched_at
    )
    created = membership.new_record?
    membership.assign_attributes(
      ends_on: inferred_membership_end_on(player),
      primary_position: position&.abbreviation,
      secondary_positions: [],
      jersey_number: entry["jerseyNumber"].presence || person_jersey_number(entry),
      source_status_code: status_payload["code"],
      source_status_description: status_payload["description"],
      source_url: source_url,
      last_synced_at: fetched_at,
      raw_data: entry
    )
    membership.save!
    summary[created ? :created_membership_count : :updated_membership_count] += 1
  end

  def inferred_membership_end_on(player)
    future_start = player.team_memberships.where("starts_on > ?", as_of).minimum(:starts_on)
    return future_start - 1.day if future_start
    return Date.new(season, 12, 31) if season < Date.current.year

    nil
  end

  def close_other_team_memberships!(player, team, summary)
    player.team_memberships
      .where(source_name: SOURCE_NAME)
      .where.not(team: team)
      .active_on(as_of)
      .find_each do |membership|
        close_membership!(membership)
        summary[:closed_membership_count] += 1
      end
  end

  def close_missing_memberships!(team, imported_player_ids, summary)
    team.team_memberships
      .where(source_name: SOURCE_NAME)
      .active_on(as_of)
      .where.not(player_id: imported_player_ids)
      .find_each do |membership|
        close_membership!(membership)
        summary[:closed_membership_count] += 1
      end
  end

  def close_membership!(membership)
    if membership.starts_on >= as_of
      membership.destroy!
    else
      membership.update!(ends_on: as_of - 1.day, last_synced_at: fetched_at)
    end
  end

  def entries_by_player_id
    @entries_by_player_id ||= Array(payload["roster"]).each_with_object({}) do |entry, entries|
      person_id = entry.dig("person", "id").to_s
      entries[person_id] = entry
    end
  end

  def duplicate_entry_count
    Array(payload["roster"]).length - entries_by_player_id.length
  end

  def person_jersey_number(entry)
    entry.dig("person", "primaryNumber").presence
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

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [])
    { success: false, message: message, data: { errors: errors } }
  end
end
