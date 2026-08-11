require "set"

class MlbPlayerTeamHistoryImporter
  SOURCE_NAME = "MLB Stats API transactions"
  ROSTER_STATUS = "organization"
  JOIN_TYPE_CODES = %w[CL PUR SE SFA TR].freeze
  JOIN_DESCRIPTIONS = /claimed|purchased|selected|signed as free agent|trade/i
  LEAVE_DESCRIPTIONS = /declared free agency|elected free agency|released|retired/i

  def self.call(player:, payload:, source_url: nil, fetched_at: Time.current)
    new(player: player, payload: payload, source_url: source_url, fetched_at: fetched_at).call
  end

  def initialize(player:, payload:, source_url: nil, fetched_at: Time.current)
    @player = player
    @payload = payload
    @source_url = source_url
    @fetched_at = fetched_at.is_a?(Time) ? fetched_at : Time.zone.parse(fetched_at.to_s)
  end

  def call
    return failure("Player is required") unless player.is_a?(Player)
    return failure("MLB transactions payload must include a transactions array") unless transactions.is_a?(Array)
    return failure("Fetched-at timestamp is required") if fetched_at.nil?

    tenures = build_tenures
    TeamMembership.transaction do
      player.team_memberships.where(source_name: SOURCE_NAME).delete_all
      tenures.each { |tenure| create_membership!(tenure) }
      player.refresh_current_team!
    end

    success(
      "Synchronized #{tenures.length} MLB organization tenures",
      transaction_count: transactions.length,
      tenure_count: tenures.length,
      skipped_team_ids: skipped_team_ids.to_a.sort
    )
  rescue ActiveRecord::ActiveRecordError => error
    failure("Failed to import MLB organization history: #{error.message}")
  end

  private

  attr_reader :player, :payload, :source_url, :fetched_at

  def transactions
    payload.is_a?(Hash) ? payload["transactions"] : nil
  end

  def build_tenures
    @skipped_team_ids = Set.new
    tenures = []
    current = nil

    sorted_transactions.each do |transaction|
      date = transaction_date(transaction)
      next if date.nil?

      from_team = local_team(transaction["fromTeam"])
      to_team = local_team(transaction["toTeam"])

      if leaving_organization?(transaction)
        if current && [ from_team&.id, to_team&.id ].compact.include?(current[:team].id)
          current[:ends_on] = date - 1.day
          current[:end_transaction] = transaction
          current = nil
        end
        next
      end

      next unless organization_join?(transaction, from_team, to_team)
      next if to_team.nil? || current&.dig(:team)&.id == to_team.id

      if current
        current[:ends_on] = date - 1.day
        current[:end_transaction] = transaction
      end
      current = {
        team: to_team,
        starts_on: date,
        ends_on: nil,
        start_transaction: transaction,
        end_transaction: nil
      }
      tenures << current
    end

    tenures.select { |tenure| tenure[:ends_on].nil? || tenure[:ends_on] >= tenure[:starts_on] }
  end

  def sorted_transactions
    transactions.sort_by do |transaction|
      [ transaction_date(transaction) || Date.new(9999, 12, 31), transaction.fetch("id", 0).to_i  ]
    end
  end

  def transaction_date(transaction)
    Date.iso8601(transaction["date"].presence || transaction["effectiveDate"].to_s)
  rescue Date::Error
    nil
  end

  def organization_join?(transaction, from_team, to_team)
    return true if from_team && to_team && from_team.id != to_team.id

    JOIN_TYPE_CODES.include?(transaction["typeCode"].to_s.upcase) ||
      transaction["typeDesc"].to_s.match?(JOIN_DESCRIPTIONS)
  end

  def leaving_organization?(transaction)
    transaction["typeDesc"].to_s.match?(LEAVE_DESCRIPTIONS) ||
      transaction["description"].to_s.match?(LEAVE_DESCRIPTIONS)
  end

  def local_team(team_payload)
    mlb_id = Integer(team_payload&.fetch("id", nil), exception: false)
    return if mlb_id.nil?

    team = teams_by_mlb_id[mlb_id]
    @skipped_team_ids << mlb_id if team.nil?
    team
  end

  def teams_by_mlb_id
    @teams_by_mlb_id ||= Team.where(mlb_id: transaction_team_ids).index_by(&:mlb_id)
  end

  def transaction_team_ids
    transactions.flat_map do |transaction|
      [ transaction.dig("fromTeam", "id"), transaction.dig("toTeam", "id") ]
    end.filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def skipped_team_ids
    @skipped_team_ids ||= Set.new
  end

  def create_membership!(tenure)
    player.team_memberships.create!(
      team: tenure.fetch(:team),
      starts_on: tenure.fetch(:starts_on),
      ends_on: tenure[:ends_on],
      roster_status: ROSTER_STATUS,
      source_name: SOURCE_NAME,
      source_status_description: "Organization tenure",
      source_url: source_url,
      last_synced_at: fetched_at,
      raw_data: {
        "start_transaction" => tenure[:start_transaction],
        "end_transaction" => tenure[:end_transaction]
      }
    )
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
