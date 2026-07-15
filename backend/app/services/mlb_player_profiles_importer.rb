class MlbPlayerProfilesImporter
  def self.call(payload:, requested_mlb_ids:, fetched_at: Time.current)
    new(payload: payload, requested_mlb_ids: requested_mlb_ids, fetched_at: fetched_at).call
  end

  def initialize(payload:, requested_mlb_ids:, fetched_at: Time.current)
    @payload = payload
    @requested_mlb_ids = Array(requested_mlb_ids).filter_map { |value| Integer(value, exception: false) }.uniq
    @fetched_at = parse_time(fetched_at)
  end

  def call
    errors = input_errors
    return failure("MLB player profile import validation failed", errors) if errors.any?

    summary = persist
    success("Imported #{summary[:profile_count]} MLB player profiles", summary)
  rescue ArgumentError => e
    failure("MLB player profile import validation failed", [ e.message ])
  rescue ActiveRecord::RecordInvalid => e
    failure("MLB player profile import validation failed", e.record.errors.full_messages)
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to import MLB player profiles: #{e.message}")
  end

  private

  attr_reader :payload, :requested_mlb_ids, :fetched_at

  def input_errors
    errors = []
    errors << "Payload must be a JSON object" unless payload.is_a?(Hash)
    errors << "Payload must include a people array" unless payload.is_a?(Hash) && payload["people"].is_a?(Array)
    errors << "At least one requested MLB id is required" if requested_mlb_ids.empty?
    errors << "Fetched-at timestamp is required" if fetched_at.nil?
    errors
  end

  def persist
    summary = {
      profile_count: 0,
      created_profile_count: 0,
      updated_profile_count: 0,
      position_assignment_count: 0,
      missing_player_count: 0,
      missing_mlb_ids: []
    }
    received_mlb_ids = []

    PlayerProfile.transaction do
      people_by_mlb_id.each do |mlb_id, person|
        received_mlb_ids << mlb_id
        player = Player.find_by(mlb_id: mlb_id)
        if player.nil?
          summary[:missing_player_count] += 1
          summary[:missing_mlb_ids] << mlb_id
          next
        end

        result = MlbPlayerProfileUpserter.call(player: player, person: person, fetched_at: fetched_at)
        summary[:profile_count] += 1
        summary[result[:profile_created] ? :created_profile_count : :updated_profile_count] += 1
        summary[:position_assignment_count] += result[:position_assignment_count]
      end
    end

    summary[:missing_mlb_ids] |= requested_mlb_ids - received_mlb_ids
    summary[:missing_player_count] = summary[:missing_mlb_ids].length
    summary
  end

  def people_by_mlb_id
    @people_by_mlb_id ||= payload["people"].each_with_object({}) do |person, people|
      mlb_id = Integer(person["id"], exception: false)
      raise ArgumentError, "Person payload is missing id" if mlb_id.nil?

      people[mlb_id] = person
    end
  end

  def parse_time(value)
    return value.in_time_zone if value.respond_to?(:in_time_zone)
    return if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message, errors = [])
    { success: false, message: message, data: { errors: errors } }
  end
end
