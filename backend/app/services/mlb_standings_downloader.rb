require "json"
require "net/http"

class MlbStandingsDownloader
  def self.call(season:)
    new(season:).call
  end

  def initialize(season:)
    @season = season.to_i
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/standings"
    uri.query = {
      leagueId: "103,104",
      season: season,
      standingsTypes: "regularSeason",
      hydrate: "team"
    }.to_query

    payload = JSON.parse(request(uri).body)
    Array(payload["records"]).flat_map { |record| Array(record["teamRecords"]) }.each_with_object({}) do |row, standings|
      team_id = Integer(row.dig("team", "id"), exception: false)
      next unless team_id

      standings[team_id] = {
        "wins" => row["wins"],
        "losses" => row["losses"]
      }
    end
  end

  private

  attr_reader :season

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
