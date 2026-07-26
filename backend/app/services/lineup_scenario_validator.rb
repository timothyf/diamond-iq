class LineupScenarioValidator
  REQUIRED_POSITIONS = LineupScenarioEntry::DEFENSIVE_POSITIONS.freeze

  def self.call(team:, entries:, on: Date.current)
    new(team: team, entries: entries, on: on).call
  end

  def initialize(team:, entries:, on:)
    @team = team
    @entries = Array(entries)
    @on = on
  end

  def call
    violations = []
    violations << "A lineup must contain exactly nine players." unless entries.length == 9
    violations << "Batting-order slots must be the unique numbers 1 through 9." unless valid_slots?
    violations << "Each player can appear only once in a lineup." unless unique_players?
    violations << "Assign exactly one C, 1B, 2B, 3B, SS, LF, CF, RF, and DH." unless valid_positions?
    violations.concat(ineligible_player_violations)
    violations.uniq
  end

  private

  attr_reader :team, :entries, :on

  def valid_slots?
    entries.map { |entry| integer(entry[:batting_slot] || entry["batting_slot"]) }.sort == (1..9).to_a
  end

  def unique_players?
    player_ids = entries.map { |entry| integer(entry[:player_id] || entry["player_id"]) }
    player_ids.none?(&:nil?) && player_ids.uniq.length == player_ids.length
  end

  def valid_positions?
    entries.map { |entry| (entry[:defensive_position] || entry["defensive_position"]).to_s.upcase }.sort == REQUIRED_POSITIONS.sort
  end

  def ineligible_player_violations
    player_ids = entries.filter_map { |entry| integer(entry[:player_id] || entry["player_id"]) }.uniq
    return [] if player_ids.empty?

    active_ids = team.team_memberships.active_on(on).where(roster_status: "active").where(player_id: player_ids).pluck(:player_id)
    unavailable_ids = player_ids - active_ids
    unavailable_ids.empty? ? [] : [ "Every lineup player must be active and available on the team roster." ]
  end

  def integer(value)
    Integer(value, exception: false)
  end
end
