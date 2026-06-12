class PlayerSeasonStatsIndexQuery
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  DEFAULT_SORT = "season"
  SORT_FIELDS = {
    "season" => "player_season_stats.season",
    "value" => "player_season_stats.value",
    "player_name" => "players.last_name",
    "team_name" => "teams.team_name",
    "stat_type_name" => "stat_types.name",
    "category" => "stat_types.category",
    "created_at" => "player_season_stats.created_at",
    "updated_at" => "player_season_stats.updated_at"
  }.freeze

  def initialize(params:, relation: PlayerSeasonStat.all)
    @params = params
    @relation = relation
  end

  def results
    filtered_relation
      .order(Arel.sql("#{sort_column} #{sort_direction}, player_season_stats.id ASC"))
      .offset((page - 1) * per_page)
      .limit(per_page)
  end

  def metadata
    {
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages,
      sort: normalized_sort,
      filters: normalized_filters
    }
  end

  private

  attr_reader :params, :relation

  def base_relation
    @base_relation ||= relation
      .includes(:stat_type, player: :team)
      .joins(:stat_type, player: :team)
  end

  def filtered_relation
    @filtered_relation ||= begin
      scope = base_relation

      if normalized_filters[:season].present?
        scope = scope.where(season: normalized_filters[:season])
      else
        if normalized_filters[:season_start].present?
          scope = scope.where("player_season_stats.season >= ?", normalized_filters[:season_start])
        end

        if normalized_filters[:season_end].present?
          scope = scope.where("player_season_stats.season <= ?", normalized_filters[:season_end])
        end
      end

      if normalized_filters[:team_id].present?
        scope = scope.where(players: { team_id: normalized_filters[:team_id] })
      end

      if normalized_filters[:player_id].present?
        scope = scope.where(player_id: normalized_filters[:player_id])
      end

      if normalized_filters[:team_name].present?
        team_name_pattern = like_pattern(normalized_filters[:team_name])
        scope = scope.where("teams.name ILIKE :pattern OR teams.team_name ILIKE :pattern", pattern: team_name_pattern)
      end

      if normalized_filters[:player_name].present?
        player_name_pattern = like_pattern(normalized_filters[:player_name])
        scope = scope.where(
          "concat_ws(' ', players.first_name, players.last_name) ILIKE :pattern OR players.last_name ILIKE :pattern",
          pattern: player_name_pattern
        )
      end

      if normalized_filters[:stat_type_name].present?
        stat_type_pattern = like_pattern(normalized_filters[:stat_type_name])
        scope = scope.where("stat_types.name ILIKE :pattern OR stat_types.label ILIKE :pattern", pattern: stat_type_pattern)
      end

      if normalized_filters[:category].present?
        scope = scope.where("stat_types.category ILIKE ?", like_pattern(normalized_filters[:category]))
      end

      if normalized_filters[:min_value].present?
        scope = scope.where("player_season_stats.value >= ?", normalized_filters[:min_value])
      end

      if normalized_filters[:max_value].present?
        scope = scope.where("player_season_stats.value <= ?", normalized_filters[:max_value])
      end

      scope
    end
  end

  def normalized_filters
    @normalized_filters ||= begin
      filters = raw_filters
        .slice(
          "season",
          "season_start",
          "season_end",
          "team_id",
          "player_id",
          "team_name",
          "player_name",
          "stat_type_name",
          "category",
          "min_value",
          "max_value"
        )
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
        .compact_blank

      integer_filter!(filters, "season")
      integer_filter!(filters, "season_start")
      integer_filter!(filters, "season_end")
      integer_filter!(filters, "team_id")
      integer_filter!(filters, "player_id")
      decimal_filter!(filters, "min_value")
      decimal_filter!(filters, "max_value")

      normalize_season_bounds!(filters)

      filters.symbolize_keys
    end
  end

  def raw_filters
    filters = params.fetch("filter", params.fetch(:filter, {}))
    filters.respond_to?(:to_h) ? filters.to_h.deep_stringify_keys : {}
  end

  def page
    @page ||= positive_integer(params["page"] || params[:page], DEFAULT_PAGE)
  end

  def per_page
    @per_page ||= [positive_integer(params["per_page"] || params[:per_page], DEFAULT_PER_PAGE), MAX_PER_PAGE].min
  end

  def total_count
    @total_count ||= filtered_relation.count
  end

  def total_pages
    return 0 if total_count.zero?

    (total_count.to_f / per_page).ceil
  end

  def requested_sort
    @requested_sort ||= (params["sort"] || params[:sort]).presence || DEFAULT_SORT
  end

  def requested_sort_field
    requested_sort.delete_prefix("-")
  end

  def sort_field
    @sort_field ||= SORT_FIELDS.key?(requested_sort_field) ? requested_sort_field : DEFAULT_SORT
  end

  def sort_column
    SORT_FIELDS.fetch(sort_field)
  end

  def sort_direction
    return "ASC" unless sort_field == requested_sort_field

    requested_sort.start_with?("-") ? "DESC" : "ASC"
  end

  def normalized_sort
    prefix = sort_direction == "DESC" ? "-" : ""
    "#{prefix}#{sort_field}"
  end

  def positive_integer(value, fallback)
    integer = value.to_i
    integer.positive? ? integer : fallback
  end

  def integer_filter!(filters, key)
    return unless filters[key].present?

    integer = Integer(filters[key], exception: false)
    integer.present? ? filters[key] = integer : filters.delete(key)
  end

  def decimal_filter!(filters, key)
    return unless filters[key].present?

    filters[key] = BigDecimal(filters[key].to_s)
  rescue ArgumentError
    filters.delete(key)
  end

  def like_pattern(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end

  def normalize_season_bounds!(filters)
    return unless filters["season_start"].present? && filters["season_end"].present?
    return unless filters["season_start"] > filters["season_end"]

    filters["season_start"], filters["season_end"] = filters["season_end"], filters["season_start"]
  end
end
