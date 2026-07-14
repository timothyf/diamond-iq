class TeamMembershipsRosterStatusQuery
  DEFAULT_STATUSES = ["active", "40-man"].freeze

  def initialize(params:, relation: TeamMembership.all)
    @params = params
    @relation = relation
  end

  def grouped_results
    grouped = scoped_relation.group_by { |membership| canonical_roster_status(membership.roster_status) }

    requested_canonical_statuses.each_with_object({}) do |status, hash|
      hash[status] = Array(grouped[status])
    end
  end

  def metadata
    {
      on: on_date,
      team_id: normalized_team_id,
      statuses: requested_canonical_statuses,
      counts: grouped_results.transform_values(&:count)
    }
  end

  private

  attr_reader :params, :relation

  def scoped_relation
    @scoped_relation ||= begin
      scope = relation.includes(:player, :team).active_on(on_date)
      scope = scope.where(team_id: normalized_team_id) if normalized_team_id.present?
      scope.where("LOWER(roster_status) IN (?)", requested_raw_statuses.map(&:downcase)).order(:team_id, :roster_status, :starts_on, :id)
    end
  end

  def on_date
    @on_date ||= parse_date(params["on"]) || Date.current
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def normalized_team_id
    @normalized_team_id ||= begin
      value = params["team_id"] || params[:team_id]
      integer = Integer(value, exception: false)
      integer if integer.present?
    end
  end

  def requested_canonical_statuses
    @requested_canonical_statuses ||= begin
      statuses = Array(params["statuses"] || params[:statuses]).presence || DEFAULT_STATUSES
      statuses.map { |status| canonical_roster_status(status) }.uniq
    end
  end

  def requested_raw_statuses
    @requested_raw_statuses ||= requested_canonical_statuses.flat_map { |status| roster_status_aliases(status) }.uniq
  end

  def canonical_roster_status(value)
    normalized = value.to_s.strip.downcase
    return "40-man" if %w[40-man 40_man forty_man fortyman].include?(normalized)

    normalized.presence || "unknown"
  end

  def roster_status_aliases(status)
    return %w[40-man 40_man forty_man fortyman] if status == "40-man"

    [status]
  end
end