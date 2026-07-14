class TeamMembershipsActiveTodayQuery
  def initialize(params:, relation: TeamMembership.all)
    @params = params
    @relation = relation
  end

  def results
    scoped_relation.to_a
  end

  def metadata
    {
      on: on_date,
      total_count: scoped_relation.count,
      filters: normalized_filters
    }
  end

  private

  attr_reader :params, :relation

  def scoped_relation
    @scoped_relation ||= begin
      scope = relation.includes(:player, :team).active_on(on_date)
      scope = scope.where(team_id: normalized_filters[:team_id]) if normalized_filters[:team_id].present?
      scope = scope.where(player_id: normalized_filters[:player_id]) if normalized_filters[:player_id].present?

      if normalized_filters[:roster_status].present?
        scope = scope.where("LOWER(roster_status) = ?", normalized_filters[:roster_status].downcase)
      end

      scope.order(:team_id, :roster_status, :starts_on, :id)
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

  def on_date
    @on_date ||= begin
      parsed = Date.iso8601(params["on"].to_s)
      parsed
    rescue ArgumentError
      Date.current
    end
  end

  def raw_filters
    filters = params.fetch("filter", params.fetch(:filter, {}))
    filters.respond_to?(:to_h) ? filters.to_h.deep_stringify_keys : {}
  end

  def integer_filter!(filters, key)
    return unless filters[key].present?

    integer = Integer(filters[key], exception: false)
    integer.present? ? filters[key] = integer : filters.delete(key)
  end
end