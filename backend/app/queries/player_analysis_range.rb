class PlayerAnalysisRange
  PRESETS = %w[season 7 14 30 custom].freeze
  PA_WINDOWS = [ 25, 50, 100 ].freeze
  PITCH_WINDOWS = [ 50, 100, 250 ].freeze

  attr_reader :preset, :start_date, :end_date, :previous_start_date, :previous_end_date,
    :plate_appearance_window, :pitch_window

  def self.resolve(player:, params: {})
    new(player: player, params: params).resolve
  end

  def initialize(player:, params: {})
    @player = player
    @params = params.to_h.with_indifferent_access
  end

  def resolve
    @preset = params[:range].presence || "season"
    raise ArgumentError, "Range must be one of: #{PRESETS.join(', ')}" unless PRESETS.include?(preset)

    @plate_appearance_window = allowed_window(:pa_window, PA_WINDOWS, 50)
    @pitch_window = allowed_window(:pitch_window, PITCH_WINDOWS, 100)
    resolve_dates
    raise ArgumentError, "End date must be on or after start date" if end_date < start_date

    length = (end_date - start_date).to_i + 1
    @previous_end_date = start_date - 1.day
    @previous_start_date = start_date - length.days
    self
  end

  def to_h
    {
      preset: preset,
      start_date: start_date,
      end_date: end_date,
      previous_start_date: previous_start_date,
      previous_end_date: previous_end_date,
      plate_appearance_window: plate_appearance_window,
      pitch_window: pitch_window
    }
  end

  private

  attr_reader :player, :params

  def resolve_dates
    if preset == "custom"
      @start_date = required_date(:start_date)
      @end_date = required_date(:end_date)
      return
    end

    @end_date = latest_data_date || Date.current
    @start_date = if preset == "season"
      Date.new(end_date.year, 1, 1)
    else
      end_date - (preset.to_i - 1).days
    end
  end

  def latest_data_date
    @latest_data_date ||= [
      PlayerBattingDaily.where(player: player).maximum(:metric_date),
      PlayerPitchingDaily.where(player: player).maximum(:metric_date),
      BatterSplitSummary.where(player: player).maximum(:metric_date),
      PitcherSplitSummary.where(player: player).maximum(:metric_date),
      PitcherPitchTypeDaily.where(player: player).maximum(:metric_date),
      PitchDatum.where(batter: player.mlb_id).maximum(:game_date),
      PitchDatum.where(pitcher: player.mlb_id).maximum(:game_date)
    ].compact.max
  end

  def required_date(key)
    value = params[key].presence
    raise ArgumentError, "#{key.to_s.humanize} is required for a custom range" if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error
    raise ArgumentError, "#{key.to_s.humanize} must be a valid ISO date"
  end

  def allowed_window(key, choices, default)
    value = params[key].presence
    return default if value.blank?

    parsed = Integer(value, exception: false)
    raise ArgumentError, "#{key.to_s.humanize} must be one of: #{choices.join(', ')}" unless choices.include?(parsed)

    parsed
  end
end
