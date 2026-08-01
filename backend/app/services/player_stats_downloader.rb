require "csv"
require "json"
require "net/http"

class PlayerStatsDownloader
  BASE_URL = "https://bdfed.stitch.mlbinfra.com/bdfed/stats/player"
  BASEBALL_REFERENCE_WAR_URL = "https://www.baseball-reference.com/data/war_daily_pitch.txt"
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
    "wOBA",
    "wRC+",
    "OPS+",
    "Offense",
    "BaseRunning",
    "Defense",
    "GB%",
    "FB%",
    "LD%",
    "Pull%",
    "Cent%",
    "Oppo%",
    "Swing%",
    "O-Swing%",
    "Contact%",
    "Z-Contact%",
    "SwStr%",
    "K%",
    "BB%",
    "K-BB%",
    "K/BB",
    "BABIP",
    "LOB%",
    "ERA-",
    "FIP-",
    "FIP",
    "xFIP",
    "xFIP-",
    "SIERA",
    "xERA",
    "wOBAAllowed",
    "xwOBAAllowed",
    "RA9-Wins",
    "WPA",
    "WPA/LI",
    "RE24",
    "Clutch",
    "RAR",
    "RAA",
    "PitchingRuns",
    "pLI",
    "SD",
    "MD",
    "ballsInPlay",
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

    merge_fangraphs_values(rows, year)
    if category == "pitching"
      merge_baseball_reference_values(rows, year)
      merge_statcast_values(rows, year)
    end
    rows
  end

  def merge_fangraphs_values(rows, year)
    fangraphs_values = fetch_fangraphs_values(year)
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless fangraphs_values.key?(player_id)

      row.merge!(fangraphs_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download FanGraphs values for #{category} #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_fangraphs_values(year)
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
      next unless mlb_id

      player_values = { "WAR" => row["WAR"] }.compact
      if category == "batting"
        player_values["wOBA"] = row["wOBA"] if row["wOBA"].present?
        player_values["wRC+"] = row["wRC+"] if row["wRC+"].present?
        player_values["Offense"] = row["Offense"] if row["Offense"].present?
        player_values["BaseRunning"] = row["BaseRunning"] if row["BaseRunning"].present?
        player_values["Defense"] = row["Defense"] if row["Defense"].present?
        player_values["GB%"] = row["GB%"] if row["GB%"].present?
        player_values["FB%"] = row["FB%"] if row["FB%"].present?
        player_values["LD%"] = row["LD%"] if row["LD%"].present?
        player_values["Pull%"] = row["Pull%"] if row["Pull%"].present?
        player_values["Cent%"] = row["Cent%"] if row["Cent%"].present?
        player_values["Oppo%"] = row["Oppo%"] if row["Oppo%"].present?
        player_values["Swing%"] = row["Swing%"] if row["Swing%"].present?
        player_values["O-Swing%"] = row["O-Swing%"] if row["O-Swing%"].present?
        player_values["Contact%"] = row["Contact%"] if row["Contact%"].present?
        player_values["Z-Contact%"] = row["Z-Contact%"] if row["Z-Contact%"].present?
        player_values["SwStr%"] = row["SwStr%"] if row["SwStr%"].present?
        player_values["ballsInPlay"] = row["bipCount"] if row["bipCount"].present?
        ops_plus = calculated_ops_plus(row)
        player_values["OPS+"] = ops_plus if ops_plus
      else
        %w[
          K% BB% K-BB% K/BB BABIP LOB% ERA- FIP FIP- xFIP xFIP- SIERA xERA
          RA9-Wins WPA WPA/LI RE24 Clutch RAR RAA PitchingRuns pLI SD MD
        ].each do |key|
          player_values[key] = row[key] if row[key].present?
        end
      end
      values[mlb_id] = player_values if player_values.any?
    end
  end

  def merge_statcast_values(rows, year)
    statcast_values = fetch_statcast_values(year).merge(fetch_statcast_run_values(year)) do |_player_id, expected_values, run_values|
      expected_values.merge(run_values)
    end
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless statcast_values.key?(player_id)

      row.merge!(statcast_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Statcast values for pitching #{year}: #{e.class}: #{e.message}")
    rows
  end

  def merge_baseball_reference_values(rows, year)
    year_values = fetch_baseball_reference_values.fetch(year, {})
    rows.each do |row|
      player_id = row["mlb_id"].to_i
      next unless year_values.key?(player_id)

      row.merge!(year_values.fetch(player_id))
    end
  rescue StandardError => e
    Rails.logger.warn("Unable to download Baseball-Reference values for pitching #{year}: #{e.class}: #{e.message}")
    rows
  end

  def fetch_baseball_reference_values
    @fetch_baseball_reference_values ||= begin
      uri = URI(BASEBALL_REFERENCE_WAR_URL)
      response = request_csv(uri)
      csv_body = utf8_csv_body(response.body)
      values = Hash.new { |hash, year| hash[year] = {} }

      CSV.parse(csv_body, headers: true).each do |row|
        year = Integer(row["year_ID"], exception: false)
        player_id = Integer(row["mlb_ID"], exception: false)
        next unless year && player_id && year.between?(start_year, end_year)

        values[year][player_id] = { "RAA" => Float(row["runs_above_avg"], exception: false) }.compact
      end
      values
    end
  end

  def fetch_statcast_values(year)
    uri = URI("https://baseballsavant.mlb.com/leaderboard/custom")
    uri.query = {
      year: year,
      type: "pitcher",
      min: 1,
      selections: "player_id,player_name,woba,xwoba",
      csv: "true"
    }.to_query

    response = request_csv(uri)
    csv_body = utf8_csv_body(response.body)
    CSV.parse(csv_body, headers: true).each_with_object({}) do |row, values|
      player_id = Integer(row["player_id"], exception: false)
      next unless player_id

      values[player_id] = {
        "wOBAAllowed" => Float(row["woba"], exception: false),
        "xwOBAAllowed" => Float(row["xwoba"], exception: false)
      }.compact
    end
  end

  def fetch_statcast_run_values(year)
    uri = URI("https://baseballsavant.mlb.com/leaderboard/swing-take")
    uri.query = {
      year: year,
      type: "All",
      group: "Pitcher",
      sub_type: "All",
      min: 1,
      csv: "true"
    }.to_query

    response = request_csv(uri)
    CSV.parse(utf8_csv_body(response.body), headers: true).each_with_object({}) do |row, values|
      player_id = Integer(row["player_id"], exception: false)
      next unless player_id

      pitching_runs = Float(row["runs_all"], exception: false)
      values[player_id] = { "PitchingRuns" => pitching_runs } if pitching_runs
    end
  end

  def request_csv(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = DEFAULT_TIMEOUT_SECONDS
    http.read_timeout = DEFAULT_TIMEOUT_SECONDS
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "text/csv,*/*"

    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def utf8_csv_body(body)
    body.dup.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF")
  end

  def calculated_ops_plus(row)
    obp_plus = Float(row["OBP+"], exception: false)
    slg_plus = Float(row["SLG+"], exception: false)
    return if obp_plus.nil? || slg_plus.nil?

    obp_plus + slg_plus - 100
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
        nested_key = [ prefix, key ].compact.join(".")
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
