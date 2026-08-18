class MlbTradesSync
  def self.call(mlb_transaction_ids:)
    new(mlb_transaction_ids: mlb_transaction_ids).call
  end

  def initialize(mlb_transaction_ids:)
    @mlb_transaction_ids = Array(mlb_transaction_ids)
      .filter_map { |value| Integer(value, exception: false) }
      .select(&:positive?)
      .uniq
  end

  def call
    summary = {
      selected_trade_count: mlb_transaction_ids.length,
      synchronized_trade_count: 0,
      participant_count: 0,
      failures: []
    }

    mlb_transaction_ids.each do |mlb_transaction_id|
      result = sync_trade(mlb_transaction_id)
      if result[:success]
        summary[:synchronized_trade_count] += 1
        summary[:participant_count] += result.dig(:data, :participant_count).to_i
      else
        summary[:failures] << { mlb_transaction_id: mlb_transaction_id, message: result[:message] }
      end
    end

    {
      success: summary[:failures].empty?,
      message: "Synchronized #{summary[:synchronized_trade_count]} of #{summary[:selected_trade_count]} MLB trades",
      data: summary
    }
  end

  private

  attr_reader :mlb_transaction_ids

  def sync_trade(mlb_transaction_id)
    download = MlbTradeDetailsDownloader.call(mlb_transaction_id: mlb_transaction_id)
    return download unless download[:success]

    data = download.fetch(:data)
    MlbTradeImporter.call(
      payload: data.fetch(:payload),
      source_url: data.fetch(:source_url),
      fetched_at: data.fetch(:fetched_at)
    )
  end
end
