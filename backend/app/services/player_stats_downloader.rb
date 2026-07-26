require "csv"
require "json"
require "net/http"

class PlayerStatsDownloader
  BASE_URL = "https://bdfed.stitch.mlbinfra.com/bdfed/stats/player"
  LIMIT = 1_000
  DEFAULT_TIMEOUT_SECONDS = 60
  USER_AGENT = "Mozilla/5.0 (compatible; shopify-prep-project-mlb-season-stats/1.0)"

  CATEGORY_CONFIG = {
    "batting" => {
      group: "hitting",
      stat_type: "batter",
      sort_stat: "onBasePlusSlugging",
      order: "desc",
      referer: "https://www.mlb.com/stats/"
    },
    "pitching" => {
      group: "pitching",
      stat_type: "pitcher",
      sort_stat: "earnedRunAverage",
      order: "asc",
      referer: "https://www.mlb.com/stats/pitching/"
    }
  }.freeze

  PREFERRED_COLUMNS = [
    "source_season",
    "season",
    "fetched_at_utc",
    "stat_type",
    "mlb_id",
    "playerId",
    "player.id",
    "playerName",
    "player.fullName",
    "playerFirstName",
    "playerLastName",
    "playerUseName",
    "firstName",
    "lastName",
    "teamId",
    "team.id",
    "teamAbbrev",
    "team.abbreviation",
    "teamName",
    "team.name",
    "teamShortName",
    "team.shortName",
    "gamesPlayed",
    "plateAppearances",
    "atBats",
    "runs",
    "hits",
    "doubles",
    "triples",
    "homeRuns",
    "rbi",
    "baseOnBalls",
    "intentionalWalks",
    "strikeOuts",
    "stolenBases",
    "caughtStealing",
    "avg",
    "obp",
    "slg",
    "ops",
    "WAR",
    "totalBases",
    "hitByPitch",
    "sacBunts",
    "sacFlies",
    "groundIntoDoublePlay",
    "wins",
    "losses",
    "earnedRunAverage",
    "gamesStarted",
    "completeGames",
    "shutouts",
    "saves",
    "saveOpportunities",
    "inningsPitched",
    "earnedRuns",
    "whip",
    "battersFaced",
    "numberOfPitches",
    "strikePercentage",
    "source_url"
  ].freeze

  attr_reader :category, :start_year, :end_year, :delay

  def self.call(category:, start_year:, end_year: Time.zone.today.year, delay: 0.0)
    new(category: category, start_year: start_year, end_year: end_year, delay: delay).call
  end

  def initialize(category:, start_year:, end_year: Time.zone.today.year, delay: 0.0)
    @category = normalize_category(category)
    @start_year = parse_year(start_year)
    @end_year = parse_year(end_year)
    @delay = delay.to_f
  end

  def call
    return failure("Category must be batting or pitching") unless config
    return failure("Start year is required") if start_year.nil?
    return failure("End year is required") if end_year.nil?
    return failure("Start year looks too early for modern MLB data") if start_year < 1876
    return failure("End year must be greater than or equal to start year") if end_year < start_year

    rows = fetch_rows
    return failure("No #{category} rows returned from MLB") if rows.empty?

    success(
      "Downloaded #{rows.length} #{category} player season rows from MLB",
      csv_data: build_csv(rows),
      row_count: rows.length,
      category: category,
      seasons: (start_year..end_year).to_a
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB response: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB stats: #{e.message}")
  end

  private

  def config
    CATEGORY_CONFIG[category]
  end

  def normalize_category(value)
    case value.to_s.strip.downcase
    when "batter", "batters", "hitting"
      "batting"
    when "pitcher", "pitchers"
      "pitching"
    else
      value.to_s.strip.downcase
    end
  end

  def parse_year(value)
    return nil if value.blank?

    Integer(value.to_s, exception: false)
  end

  def fetch_rows
    (start_year..end_year).flat_map do |year|
      fetch_year(year)
    end
  end

  def fetch_year(year)
    fetched_at_utc = Time.current.utc.iso8601
    offset = 0
    rows = []

    loop do
      url = build_url(year, offset)
      batch = extract_rows(fetch_json(url))
      break if batch.empty?

      rows.concat(batch.map { |row| normalize_row(row, year, fetched_at_utc, url) })
      break if batch.length < LIMIT

      offset += LIMIT
      sleep(delay) if delay.positive?
    end

    merge_war_values(rows, year)
    rows
  end

  def merge_war_values(rows, year)
    war_values = fetch_war_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      row["WAR"] = war_values[player_id] if war_values.key?(player_id)
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download FanGraphs WAR for #{category} #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_war_values(year)
    uri = URI("https://www.fangraphs.com/api/leaders/major-league/data")
    query = {
      pos: "all",
      stats: category == "batting" ? "bat" : "pit",
      lg: "all",
      qual: 0,
      season: year,
      season1: year,
      month: 0,
      ind: 0,
      pageitems: 20_000,
      pagenum: 1
    }.to_query
    uri.query = query

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = DEFAULT_TIMEOUT_SECONDS
    http.read_timeout = DEFAULT_TIMEOUT_SECONDS
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "application/json,text/plain,*/*"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    Array(payload["data"]).each_with_object({}) do |row, values|
      mlb_id = Integer(row["xMLBAMID"], exception: false)
      war = row["WAR"]
      values[mlb_id] = war if mlb_id && war.present?
    end
  end

  def build_url(year, offset)
    query = {
      stitch_env: "prod",
      sportId: "1",
      stats: "season",
      group: config.fetch(:group),
      playerPool: "ALL",
      gameType: "R",
      limit: LIMIT.to_s,
      sortStat: config.fetch(:sort_stat),
      order: config.fetch(:order),
      season: year.to_s,
      offset: offset.to_s
    }.to_query

    "#{BASE_URL}?#{query}"
  end

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = DEFAULT_TIMEOUT_SECONDS
    http.read_timeout = DEFAULT_TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "application/json,text/plain,*/*"
    request["Referer"] = config.fetch(:referer)

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def extract_rows(payload)
    rows = payload["stats"] || payload["data"] || payload["splits"] || []
    raise "Expected MLB response rows to be an array" unless rows.is_a?(Array)

    rows
  end

  def normalize_row(row, year, fetched_at_utc, source_url)
    flat = flatten(row)
    flat["season"] ||= year
    flat["source_season"] = year
    flat["fetched_at_utc"] = fetched_at_utc
    flat["source_url"] = source_url
    flat["stat_type"] = config.fetch(:stat_type)
    flat["mlb_id"] = flat["playerId"] || flat["player.id"]
    flat["playerFirstName"] ||= flat["firstName"] || flat["player.firstName"]
    flat["playerLastName"] ||= flat["lastName"] || flat["player.lastName"]
    flat["playerUseName"] ||= flat["useName"] || flat["player.useName"]
    flat["teamId"] ||= flat["team.id"]
    flat["teamAbbrev"] ||= flat["team.abbreviation"]
    flat["teamName"] ||= flat["team.name"]
    flat["teamShortName"] ||= flat["team.shortName"] || flat["team.teamName"]
    flat
  end

  def flatten(value, prefix = nil)
    case value
    when Hash
      value.each_with_object({}) do |(key, nested_value), flattened|
        nested_key = [prefix, key].compact.join(".")
        flattened.merge!(flatten(nested_value, nested_key))
      end
    when Array
      { prefix => value.to_json }
    else
      { prefix => value }
    end
  end

  def build_csv(rows)
    columns = preferred_columns(rows)

    CSV.generate(headers: true) do |csv|
      csv << columns
      rows.each { |row| csv << columns.map { |column| row[column] } }
    end
  end

  def preferred_columns(rows)
    available_columns = rows.flat_map(&:keys).compact.uniq
    preferred = PREFERRED_COLUMNS.select { |column| available_columns.include?(column) }
    preferred + available_columns.reject { |column| preferred.include?(column) }.sort
  end

  def success(message, data = {})
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
