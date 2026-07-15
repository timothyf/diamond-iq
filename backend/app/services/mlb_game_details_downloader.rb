require "json"
require "net/http"

class MlbGameDetailsDownloader
  BASE_URL = "https://statsapi.mlb.com/api"
  DEFAULT_TIMEOUT_SECONDS = 60
  USER_AGENT = "DiamondIQ/1.0 (MLB game detail synchronization)"

  def self.call(mlb_id:)
    new(mlb_id: mlb_id).call
  end

  def initialize(mlb_id:)
    @mlb_id = Integer(mlb_id, exception: false)
  end

  def call
    return failure("MLB game id must be a positive integer") unless mlb_id&.positive?

    fetched_at = Time.current.utc.iso8601
    boxscore_url = "#{BASE_URL}/v1/game/#{mlb_id}/boxscore"
    live_feed_url = "#{BASE_URL}/v1.1/game/#{mlb_id}/feed/live"
    boxscore = fetch_json(boxscore_url)
    live_feed = fetch_json(live_feed_url)

    success(
      "Downloaded MLB game details for #{mlb_id}",
      mlb_id: mlb_id,
      boxscore: boxscore,
      live_feed: live_feed,
      boxscore_source_url: boxscore_url,
      live_feed_source_url: live_feed_url,
      fetched_at: fetched_at
    )
  rescue JSON::ParserError => e
    failure("Failed to parse MLB game #{mlb_id} details: #{e.message}")
  rescue StandardError => e
    failure("Failed to download MLB game #{mlb_id} details: #{e.message}")
  end

  private

  attr_reader :mlb_id

  def fetch_json(url)
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = DEFAULT_TIMEOUT_SECONDS
    http.read_timeout = DEFAULT_TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = USER_AGENT
    request["Accept"] = "application/json"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def success(message, data)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message, data: {} }
  end
end
