class NoteTarget
  TYPES = %w[player game plate_appearance pitch comparison lineup_scenario acquisition_candidate].freeze
  PUBLIC_TYPES = %w[player game plate_appearance pitch comparison].freeze
  COMPARISON_PLAYER_COUNTS = (2..3).freeze

  attr_reader :type, :key

  def initialize(type:, key:)
    @type = type.to_s
    @key = normalize_key(key)
  end

  def valid?
    TYPES.include?(type) && record_present?
  end

  def readable_by?(user)
    return false unless user && valid?
    return true if PUBLIC_TYPES.include?(type)
    return true if user.admin?

    owner_id == user.id
  end

  def writable_by?(user)
    user&.can_write? && readable_by?(user)
  end

  def metadata
    case type
    when "comparison"
      players = comparison_players
      metadata = {
        "left_player_id" => players.first.id,
        "left_player_name" => players.first.full_name,
        "right_player_id" => players.last.id,
        "right_player_name" => players.last.full_name
      }
      if players.length == 3
        metadata["third_player_id"] = players[1].id
        metadata["third_player_name"] = players[1].full_name
      end
      metadata
    else
      {}
    end
  end

  private

  def normalize_key(value)
    raw = value.to_s
    if type == "comparison" && raw.match?(/\A\d+(?::\d+){1,2}\z/)
      return raw.split(":").map(&:to_i).sort.join(":")
    end

    integer = Integer(raw, exception: false)
    integer&.positive? ? integer.to_s : raw
  end

  def record_present?
    return COMPARISON_PLAYER_COUNTS.cover?(comparison_players.length) if type == "comparison"

    record.present?
  end

  def record
    @record ||= case type
    when "player" then Player.find_by(id: integer_key)
    when "game" then Game.find_by(id: integer_key)
    when "plate_appearance" then PlateAppearance.find_by(id: integer_key)
    when "pitch" then PitchDatum.find_by(id: integer_key)
    when "lineup_scenario" then LineupScenario.find_by(id: integer_key)
    when "acquisition_candidate" then WatchlistEntry.includes(:watchlist).find_by(id: integer_key)
    end
  end

  def owner_id
    case type
    when "lineup_scenario" then record&.owner_id
    when "acquisition_candidate" then record&.watchlist&.owner_id
    end
  end

  def comparison_players
    return [] unless key.match?(/\A\d+(?::\d+){1,2}\z/)

    ids = key.split(":").map(&:to_i)
    return [] unless COMPARISON_PLAYER_COUNTS.cover?(ids.length) && ids.uniq.length == ids.length

    players = Player.where(id: ids).index_by(&:id)
    ids.filter_map { |id| players[id] }
  end

  def integer_key
    Integer(key, exception: false)
  end
end
