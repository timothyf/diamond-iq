class MlbPlayerTeamHistoriesSync
  def self.call(limit: nil, mlb_ids: nil)
    new(limit: limit, mlb_ids: mlb_ids).call
  end

  def initialize(limit: nil, mlb_ids: nil)
    @limit = positive_integer(limit)
    @mlb_ids = Array(mlb_ids).flat_map { |value| value.to_s.split(",") }
      .filter_map { |value| Integer(value, exception: false) }.uniq.presence
  end

  def call
    summary = {
      selected_player_count: players.length,
      synchronized_player_count: 0,
      transaction_count: 0,
      tenure_count: 0,
      failed_player_count: 0,
      failures: []
    }

    players.each do |player|
      result = sync_player(player)
      if result[:success]
        summary[:synchronized_player_count] += 1
        summary[:transaction_count] += result.dig(:data, :transaction_count).to_i
        summary[:tenure_count] += result.dig(:data, :tenure_count).to_i
      else
        summary[:failed_player_count] += 1
        summary[:failures] << { mlb_id: player.mlb_id, name: player.full_name, message: result[:message] }
      end
    end

    {
      success: summary[:failed_player_count].zero?,
      message: "Synchronized MLB organization history for #{summary[:synchronized_player_count]} of #{summary[:selected_player_count]} players",
      data: summary
    }
  end

  private

  attr_reader :limit, :mlb_ids

  def players
    @players ||= begin
      scope = Player.order(:id)
      scope = scope.where(mlb_id: mlb_ids) if mlb_ids.present?
      scope = scope.limit(limit) if limit.present?
      scope.to_a
    end
  end

  def sync_player(player)
    download = MlbPlayerTransactionsDownloader.call(player_mlb_id: player.mlb_id)
    return download unless download[:success]

    data = download.fetch(:data)
    MlbPlayerTeamHistoryImporter.call(
      player: player,
      payload: data.fetch(:payload),
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at)
    )
  end

  def positive_integer(value)
    parsed = Integer(value, exception: false)
    parsed if parsed&.positive?
  end
end
