require "csv"

class PlayerStatsDownloader
  attr_reader :player_id, :stats_url

  def initialize(player_id, stats_url)
    @player_id = player_id
    @stats_url = stats_url
  end

  def self.call(player_id, stats_url)
    new(player_id, stats_url).call
  end

  def call
    return failure("Invalid player ID") if player_id.blank?
    return failure("Invalid stats URL") if stats_url.blank?

    download_stats
  end

  private

  def download_stats
    response = fetch_stats
    return failure(response[:error]) unless response[:success]

    parse_and_save(response[:data])
  end

  def fetch_stats
    uri = URI(stats_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      { success: true, data: response.body }
    else
      { success: false, error: "HTTP #{response.code}: #{response.message}" }
    end
  rescue StandardError => e
    { success: false, error: e.message }
  end

  def parse_and_save(data)
    parsed_rows = parse_csv(data)
    return failure("No stat rows found in CSV") if parsed_rows.empty?

    saved_count = persist_stats(parsed_rows)
    success(
      "Stats downloaded successfully for player #{player_id}",
      { saved_count: saved_count, rows: parsed_rows }
    )
  rescue CSV::MalformedCSVError => e
    failure("Failed to parse CSV: #{e.message}")
  rescue ActiveRecord::ActiveRecordError => e
    failure("Failed to save stats: #{e.message}")
  end

  def parse_csv(data)
    csv = CSV.parse(data, headers: true)

    csv.each_with_object([]) do |row, rows|
      normalized_row = normalize_row(row.to_h)
      rows << normalized_row unless normalized_row.empty?
    end
  end

  def normalize_row(row_hash)
    row_hash.each_with_object({}) do |(key, value), normalized|
      next if key.nil?

      clean_key = key.to_s.strip
      clean_value = value.is_a?(String) ? value.strip : value
      next if clean_key.empty? || clean_value.blank?

      normalized[clean_key] = clean_value
    end
  end

  def persist_stats(parsed_rows)
    timestamp = Time.current
    records = parsed_rows.each_with_index.map do |stats_data, index|
      {
        player_id: player_id.to_s,
        source_url: stats_url,
        row_number: index + 1,
        stats_data: stats_data,
        created_at: timestamp,
        updated_at: timestamp
      }
    end

    PlayerStat.transaction do
      PlayerStat.where(player_id: player_id.to_s, source_url: stats_url).delete_all
      PlayerStat.insert_all!(records)
    end

    records.length
  end

  def success(message, data = nil)
    { success: true, message: message, data: data }
  end

  def failure(message)
    { success: false, message: message }
  end
end
