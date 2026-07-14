class PlayerPositionsBackfill
  def self.call(relation: TeamMembership.current)
    new(relation: relation).call
  end

  def initialize(relation:)
    @relation = relation
  end

  def call
    summary = {
      memberships_processed: 0,
      assignments_created: 0,
      assignments_updated: 0,
      assignments_deleted: 0,
      unknown_position_codes: []
    }

    PlayerPosition.transaction do
      latest_memberships.each do |membership|
        sync_membership(membership, summary)
      end
    end

    summary[:unknown_position_codes] = summary[:unknown_position_codes].uniq.sort

    {
      success: true,
      message: "Backfilled player positions from #{summary[:memberships_processed]} current team memberships",
      data: summary
    }
  rescue StandardError => error
    {
      success: false,
      message: "Unable to backfill player positions: #{error.message}",
      data: { error: error.message }
    }
  end

  private

  attr_reader :relation

  def latest_memberships
    relation.includes(:player).to_a
      .group_by(&:player_id)
      .values
      .map { |memberships| memberships.max_by(&:starts_on) }
  end

  def sync_membership(membership, summary)
    primary_code = normalize_code(membership.primary_position)
    requested_codes = [primary_code, *Array(membership.secondary_positions).map { |code| normalize_code(code) }]
      .compact
      .uniq

    summary[:memberships_processed] += 1
    return if requested_codes.empty?

    positions_by_code = Position.where(abbreviation: requested_codes).index_by(&:abbreviation)
    unknown_codes = requested_codes - positions_by_code.keys
    summary[:unknown_position_codes].concat(unknown_codes)

    primary_code_unknown = primary_code.present? && !positions_by_code.key?(primary_code)

    unless primary_code_unknown
      membership.player.player_positions.current.primary_assignments.update_all(
        is_primary: false,
        updated_at: Time.current
      )
    end

    desired_position_ids = positions_by_code.values.map(&:id)

    requested_codes.each do |code|
      position = positions_by_code[code]
      next if position.blank?

      assignment = membership.player.player_positions.current.find_or_initialize_by(position: position)
      new_record = assignment.new_record?

      assignment.assign_attributes(
        is_primary: code == primary_code,
        source_name: membership.source_name,
        last_synced_at: membership.last_synced_at
      )

      changed = assignment.changed?
      assignment.save!

      if new_record
        summary[:assignments_created] += 1
      elsif changed
        summary[:assignments_updated] += 1
      end
    end

    return if unknown_codes.any?

    summary[:assignments_deleted] += membership.player.player_positions.current
      .where.not(position_id: desired_position_ids)
      .delete_all
  end

  def normalize_code(value)
    value.to_s.strip.upcase.presence
  end
end
