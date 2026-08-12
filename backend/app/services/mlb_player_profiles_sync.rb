class MlbPlayerProfilesSync
  def self.call(only_missing: true, batch_size: nil, limit: nil, mlb_ids: nil)
    new(only_missing: only_missing, batch_size: batch_size, limit: limit, mlb_ids: mlb_ids).call
  end

  def initialize(only_missing: true, batch_size: nil, limit: nil, mlb_ids: nil)
    @only_missing = ActiveModel::Type::Boolean.new.cast(only_missing)
    @batch_size = normalized_batch_size(batch_size)
    @limit = positive_integer(limit)
    @mlb_ids = Array(mlb_ids).flat_map { |value| value.to_s.split(",") }.filter_map { |value| Integer(value, exception: false) }.uniq.presence
  end

  def call
    summary = initial_summary

    selected_mlb_ids.each_slice(batch_size) do |batch|
      download_result = MlbPlayerProfilesDownloader.call(mlb_ids: batch)
      return failed_batch(download_result, summary) unless download_result[:success]

      import_result = import(download_result)
      return failed_batch(import_result, summary) unless import_result[:success]

      merge_summary!(summary, import_result.fetch(:data))
      summary[:batch_count] += 1
    end

    {
      success: true,
      message: "Synchronized #{summary[:profile_count]} MLB player profiles",
      data: summary
    }
  end

  private

  attr_reader :only_missing, :batch_size, :limit, :mlb_ids

  def selected_mlb_ids
    @selected_mlb_ids ||= begin
      scope = Player.order(:id)
      scope = scope.left_outer_joins(:profile).where(player_profiles: { id: nil }) if only_missing
      scope = scope.where(mlb_id: mlb_ids) if mlb_ids.present?
      scope = scope.limit(limit) if limit.present?
      scope.pluck(:mlb_id)
    end
  end

  def initial_summary
    {
      selected_player_count: selected_mlb_ids.length,
      profile_count: 0,
      created_profile_count: 0,
      updated_profile_count: 0,
      position_assignment_count: 0,
      missing_player_count: 0,
      missing_mlb_ids: [],
      batch_count: 0
    }
  end

  def import(download_result)
    data = download_result.fetch(:data)
    MlbPlayerProfilesImporter.call(
      payload: data.fetch(:payload),
      requested_mlb_ids: data.fetch(:requested_mlb_ids),
      fetched_at: data.fetch(:fetched_at)
    )
  end

  def merge_summary!(summary, batch_summary)
    %i[profile_count created_profile_count updated_profile_count position_assignment_count missing_player_count].each do |key|
      summary[key] += batch_summary.fetch(key, 0)
    end
    summary[:missing_mlb_ids] |= Array(batch_summary[:missing_mlb_ids])
  end

  def failed_batch(result, summary)
    {
      success: false,
      message: result[:message],
      data: summary.merge(errors: Array(result.dig(:data, :errors)))
    }
  end

  def normalized_batch_size(value)
    parsed = positive_integer(value) || NineLensConfig.fetch(:operations, :player_profiles, :batch_size).to_i
    [ parsed, NineLensConfig.fetch(:operations, :player_profiles, :max_people_per_request).to_i ].min
  end

  def positive_integer(value)
    parsed = Integer(value, exception: false)
    parsed if parsed&.positive?
  end
end
