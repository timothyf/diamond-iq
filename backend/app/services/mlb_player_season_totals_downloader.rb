require "json"
require "net/http"

class MlbPlayerSeasonTotalsDownloader
  GROUPS = {
    "batting" => "hitting",
    "pitching" => "pitching"
  }.freeze

  def self.call(mlb_id:, season:, category:)
    new(mlb_id:, season:, category:).call
  end

  def initialize(mlb_id:, season:, category:)
    @mlb_id = mlb_id.to_i
    @season = season.to_i
    @category = category.to_s
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/people/#{mlb_id}/stats"
    uri.query = {
      stats: "season",
      group: GROUPS.fetch(category),
      season: season,
      gameType: "R"
    }.to_query

    JSON.parse(request(uri).body).dig("stats", 0, "splits", 0, "stat") || {}
  end

  private

  attr_reader :mlb_id, :season, :category

  def base_url
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)
  end

  def request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
    request["Accept"] = "application/json"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end

  def timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end
end
