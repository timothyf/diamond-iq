class TeamMembershipsActiveRangeQuery
  def initialize(params:, relation: TeamMembership.all)
    @params = params
    @relation = relation
  end

  def results
    scoped_relation.to_a
  end

  def metadata
    {
      starts_on: starts_on,
      ends_on: ends_on,
      total_count: scoped_relation.count,
      filters: normalized_filters
    }
  end

  private

  attr_reader :params, :relation

  def scoped_relation
    @scoped_relation ||= begin
      scope = relation.includes(:player, :team)
      scope = scope.where("team_memberships.starts_on <= ? AND (team_memberships.ends_on IS NULL OR team_memberships.ends_on >= ?)", ends_on, starts_on)
      scope = scope.where(team_id: normalized_filters[:team_id]) if normalized_filters[:team_id].present?
      scope = scope.where(player_id: normalized_filters[:player_id]) if normalized_filters[:player_id].present?

      if normalized_filters[:roster_status].present?
        scope = scope.where("LOWER(roster_status) = ?", normalized_filters[:roster_status].downcase)
      end

      scope.order(:team_id, :starts_on, :id)
    end
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

  def starts_on
    @starts_on ||= begin
      parsed = parse_date(params["starts_on"]) || parse_date(params["start_on"]) || parse_date(params["on"]) || Date.current
      [parsed, ends_on].min
    end
  end

  def ends_on
    @ends_on ||= begin
      parsed = parse_date(params["ends_on"]) || parse_date(params["end_on"]) || parse_date(params["on"]) || Date.current
      parsed
    end
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
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
end