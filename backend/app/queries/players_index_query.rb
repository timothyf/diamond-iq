class PlayersIndexQuery
  DEFAULT_PAGE = 1
  DEFAULT_PER_PAGE = 25
  MAX_PER_PAGE = 100
  DEFAULT_SORT = "last_name"
  SORT_FIELDS = {
    "first_name" => "players.first_name",
    "last_name" => "players.last_name",
    "created_at" => "players.created_at",
    "updated_at" => "players.updated_at",
    "team_name" => "teams.team_name"
  }.freeze

  def initialize(params:, relation: Player.all)
    @params = params
    @relation = relation
  end

  def results
    filtered_relation
      .order(Arel.sql(order_expression))
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
    @base_relation ||= relation.includes(:team).left_outer_joins(:team)
  end

  def filtered_relation
    @filtered_relation ||= begin
      scope = base_relation

      if name_filter_requested? && normalized_filters[:name].blank?
        scope = scope.none
      elsif normalized_filters[:name].present?
        name_tokens.each do |token|
          scope = scope.where(
            <<~SQL.squish,
              players.first_name ILIKE :pattern
              OR players.last_name ILIKE :pattern
              OR concat_ws(' ', players.first_name, players.last_name) ILIKE :pattern
              OR regexp_replace(concat_ws('', players.first_name, players.last_name), '[^a-zA-Z0-9]+', '', 'g') ILIKE :compact_pattern
            SQL
            pattern: like_pattern(token),
            compact_pattern: like_pattern(compact_name(token))
          )
        end
      end

      if normalized_filters[:first_name].present?
        scope = scope.where("players.first_name ILIKE ?", like_pattern(normalized_filters[:first_name]))
      end

      if normalized_filters[:last_name].present?
        scope = scope.where("players.last_name ILIKE ?", like_pattern(normalized_filters[:last_name]))
      end

      if normalized_filters[:team_name].present?
        scope = scope.where("teams.team_name ILIKE ?", like_pattern(normalized_filters[:team_name]))
      end

      if normalized_filters[:team_id].present?
        scope = scope.where(team_id: normalized_filters[:team_id])
      end

      scope
    end
  end

  def normalized_filters
    @normalized_filters ||= begin
      filters = raw_filters
        .slice("name", "first_name", "last_name", "team_id", "team_name")
        .transform_values { |value| value.is_a?(String) ? value.strip : value }
      filters["name"] = normalize_name_query(filters["name"]) if filters["name"].is_a?(String)
      filters.compact_blank.symbolize_keys
    end
  end

  def raw_filters
    @raw_filters ||= begin
      filters = params.fetch("filter", params.fetch(:filter, {}))
      filters.respond_to?(:to_h) ? filters.to_h.deep_stringify_keys : {}
    end
  end

  def page
    @page ||= positive_integer(params["page"] || params[:page], DEFAULT_PAGE)
  end

  def per_page
    @per_page ||= [ positive_integer(params["per_page"] || params[:per_page], DEFAULT_PER_PAGE), MAX_PER_PAGE ].min
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

  def order_expression
    clauses = []
    clauses << name_relevance_expression if normalized_filters[:name].present?
    clauses << "#{sort_column} #{sort_direction}"
    clauses << "players.id ASC"
    clauses.join(", ")
  end

  def name_relevance_expression
    query = normalized_filters.fetch(:name).downcase
    quoted_query = ActiveRecord::Base.connection.quote(query)
    quoted_prefix = ActiveRecord::Base.connection.quote("#{ActiveRecord::Base.sanitize_sql_like(query)}%")

    <<~SQL.squish
      CASE
        WHEN lower(concat_ws(' ', players.first_name, players.last_name)) = #{quoted_query} THEN 0
        WHEN lower(concat_ws(' ', players.last_name, players.first_name)) = #{quoted_query} THEN 0
        WHEN players.first_name ILIKE #{quoted_prefix} THEN 1
        WHEN players.last_name ILIKE #{quoted_prefix} THEN 1
        ELSE 2
      END ASC
    SQL
  end

  def name_tokens
    @name_tokens ||= normalized_filters.fetch(:name).split
  end

  def name_filter_requested?
    raw_filters.key?("name") && raw_filters["name"].present?
  end

  def normalize_name_query(value)
    value
      .unicode_normalize(:nfkc)
      .tr("’", "'")
      .gsub(/[[:punct:]]+/, " ")
      .squish
  end

  def compact_name(value)
    value.gsub(/[^[:alnum:]]+/, "")
  end

  def positive_integer(value, fallback)
    integer = value.to_i
    integer.positive? ? integer : fallback
  end

  def like_pattern(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end
end
