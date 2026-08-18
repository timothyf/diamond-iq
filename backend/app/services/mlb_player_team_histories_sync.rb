require "set"

class MlbPlayerTeamHistoriesSync
  def self.call(limit: nil, mlb_ids: nil)
    new(limit: limit, mlb_ids: mlb_ids).call
  end

  def initialize(limit: nil, mlb_ids: nil)
    @limit = positive_integer(limit)
    @mlb_ids = Array(mlb_ids).flat_map { |value| value.to_s.split(",") }
      .filter_map { |value| Integer(value, exception: false) }.uniq.presence
    @synchronized_trade_ids = Set.new
  end

  def call
    summary = {
      selected_player_count: players.length,
      synchronized_player_count: 0,
      transaction_count: 0,
      tenure_count: 0,
      trade_count: 0,
      trade_participant_count: 0,
      failed_player_count: 0,
      failures: []
    }

    players.each do |player|
      result = sync_player(player)
      if result[:success]
        summary[:synchronized_player_count] += 1
        summary[:transaction_count] += result.dig(:data, :transaction_count).to_i
        summary[:tenure_count] += result.dig(:data, :tenure_count).to_i
        summary[:trade_count] += result.dig(:data, :trade_count).to_i
        summary[:trade_participant_count] += result.dig(:data, :trade_participant_count).to_i
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
    history = MlbPlayerTeamHistoryImporter.call(
      player: player,
      payload: data.fetch(:payload),
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at)
    )
    return history unless history[:success]

    trade_ids = Array(data.dig(:payload, "transactions")).filter_map do |transaction|
      Integer(transaction["id"], exception: false) if transaction["typeCode"].to_s.upcase == "TR"
    end.uniq
    unsynchronized_trade_ids = trade_ids.reject { |trade_id| @synchronized_trade_ids.include?(trade_id) }
    trades = MlbTradesSync.call(mlb_transaction_ids: unsynchronized_trade_ids)
    return trades unless trades[:success]

    @synchronized_trade_ids.merge(unsynchronized_trade_ids)
    history[:data] = history.fetch(:data).merge(
      trade_count: trades.dig(:data, :synchronized_trade_count).to_i,
      trade_participant_count: trades.dig(:data, :participant_count).to_i
    )
    history
  end

  def positive_integer(value)
    parsed = Integer(value, exception: false)
    parsed if parsed&.positive?
  end
end
