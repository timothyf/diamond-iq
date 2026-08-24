require "json"
require "net/http"

class MlbTeamStatsDownloader
  GROUPS = {
    "batting" => "hitting",
    "pitching" => "pitching"
  }.freeze

  STAT_KEYS = {
    "batting" => %w[
      gamesPlayed atBats runs hits doubles triples homeRuns rbi baseOnBalls strikeOuts
      stolenBases caughtStealing avg obp slg ops
    ],
    "pitching" => %w[
      wins losses era gamesPitched gamesStarted completeGames shutouts saves saveOpportunities
      inningsPitched hits runs earnedRuns homeRuns hitBatsmen baseOnBalls strikeOuts whip avg
    ]
  }.freeze

  def self.call(season:, category:)
    new(season: season, category: category).call
  end

  def initialize(season:, category:)
    @season = season.to_i
    @category = category.to_s
  end

  def call
    uri = URI(base_url)
    uri.path = "/api/v1/teams/stats"
    uri.query = {
      stats: "season",
      group: GROUPS.fetch(category),
      season: season,
      sportId: 1,
      gameType: "R"
    }.to_query

    response = request(uri)
    payload = JSON.parse(response.body)
    splits = payload.dig("stats", 0, "splits") || []

    splits.each_with_object({}) do |split, values|
      team_id = Integer(split.dig("team", "id"), exception: false)
      next unless team_id

      values[team_id] = STAT_KEYS.fetch(category).each_with_object({}) do |source_key, stats|
        value = split.dig("stat", source_key)
        stats[canonical_key(source_key)] = value if value.present?
      end
    end
  end

  private

  attr_reader :season, :category

  def base_url
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :base_url)
  end

  def timeout_seconds
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :timeout_seconds).to_i
  end

  def user_agent
    NineLensConfig.fetch(:external_services, :mlb_stats_api, :user_agents, :schedule)
  end

  def canonical_key(source_key)
    {
      "wins" => "W",
      "losses" => "L",
      "era" => "ERA",
      "gamesPitched" => "G",
      "gamesStarted" => "GS",
      "completeGames" => "CG",
      "shutouts" => "ShO",
      "saves" => "SV",
      "saveOpportunities" => "SVO",
      "earnedRuns" => "ER",
      "hitBatsmen" => "hitByPitch"
    }.fetch(source_key, source_key)
  end

  def request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = timeout_seconds
    http.read_timeout = timeout_seconds
    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = user_agent
    request["Accept"] = "application/json"
    response = http.request(request)
    raise "HTTP #{response.code}: #{response.message}" unless response.is_a?(Net::HTTPSuccess)

    response
  end
end
