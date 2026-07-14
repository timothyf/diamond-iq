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
      team_id: normalized_filters[:team_id],
      statuses: requested_canonical_statuses,
      filters: normalized_filters,
      counts: grouped_results.transform_values(&:count)
    }
  end

  private

  attr_reader :params, :relation

  def scoped_relation
    @scoped_relation ||= begin
      scope = relation.includes(:player, :team).active_on(on_date)
      scope = scope.where(team_id: normalized_filters[:team_id]) if normalized_filters[:team_id].present?
      scope = scope.where(player_id: normalized_filters[:player_id]) if normalized_filters[:player_id].present?
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

  def normalized_filters
    @normalized_filters ||= begin
      filters = raw_filters
        .slice("team_id", "player_id", "roster_status")
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
        .compact_blank

      integer_filter!(filters, "team_id")
      integer_filter!(filters, "player_id")

      filters.symbolize_keys
    end
  end

  def requested_canonical_statuses
    @requested_canonical_statuses ||= begin
      statuses = Array(params["statuses"] || params[:statuses]).presence
      statuses = [normalized_filters[:roster_status]] if statuses.blank? && normalized_filters[:roster_status].present?
      statuses ||= DEFAULT_STATUSES
      statuses.map { |status| canonical_roster_status(status) }.uniq
    end
  end

  def raw_filters
    nested_filters = params.fetch("filter", params.fetch(:filter, {}))
    nested_hash = nested_filters.respond_to?(:to_h) ? nested_filters.to_h.deep_stringify_keys : {}

    top_level_hash = params.to_h.deep_stringify_keys.slice("team_id", "player_id", "roster_status")
    top_level_hash.merge(nested_hash)
  end

  def integer_filter!(filters, key)
    return unless filters[key].present?

    integer = Integer(filters[key], exception: false)
    integer.present? ? filters[key] = integer : filters.delete(key)
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