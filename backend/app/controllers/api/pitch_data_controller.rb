module Api
  class PitchDataController < ApplicationController
    wrap_parameters false

    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 500

    def index
      rows = PitchDatum.order(game_date: :desc, game_pk: :desc, inning: :asc, at_bat_number: :asc, pitch_number: :asc)
      rows = apply_filters(rows)
      total_count = rows.count
      rows = rows.offset((page_param - 1) * per_page_param).limit(per_page_param)

      player_ids = rows.flat_map { |r| [r.pitcher, r.batter] }.compact.uniq
      player_names = Player.where(mlb_id: player_ids).pluck(:mlb_id, :first_name, :last_name)
                           .each_with_object({}) { |(id, fn, ln), h| h[id] = "#{fn} #{ln}" }

      render json: {
        data: rows.map { |row| serialize_pitch_datum(row, player_names) },
        meta: {
          count: rows.length,
          limit: per_page_param,
          page: page_param,
          per_page: per_page_param,
          total_pages: total_pages(total_count, per_page_param),
          total_count: total_count,
          available_events: available_events,
          available_pitch_types: available_pitch_types,
          data_range: data_range,
          filters: active_filters
        }
      }
    end

    def import
      uploaded_file = import_params[:file]

      if uploaded_file.blank?
        render json: { errors: ["CSV file is required"] }, status: :unprocessable_content
        return
      end

      result = PitchDataImporter.call(
        csv_data: uploaded_file.read,
        source_name: uploaded_file.original_filename
      )

      if result[:success]
        render json: { message: result[:message], data: result[:data] }, status: :created
      else
        render json: { message: result[:message], errors: Array(result.dig(:data, :errors)) }, status: :unprocessable_content
      end
    end

    def download
      permitted_params = download_params

      download_result = PitchDataDownloader.call(
        start_date: permitted_params[:start_date],
        end_date: permitted_params[:end_date],
        game_types: permitted_params[:game_types],
        chunk_days: permitted_params[:chunk_days]
      )

      unless download_result[:success]
        render json: { message: download_result[:message] }, status: :unprocessable_content
        return
      end

      import_result = PitchDataImporter.call(
        csv_data: download_result.dig(:data, :csv_data),
        source_name: "Baseball Savant pitch data #{download_result.dig(:data, :start_date)}-#{download_result.dig(:data, :end_date)}"
      )

      if import_result[:success]
        render json: {
          message: import_result[:message],
          data: import_result[:data].merge(
            downloaded_count: download_result.dig(:data, :row_count),
            downloaded_start_date: download_result.dig(:data, :start_date),
            downloaded_end_date: download_result.dig(:data, :end_date),
            downloaded_game_types: download_result.dig(:data, :game_types),
            downloaded_chunk_days: download_result.dig(:data, :chunk_days)
          )
        }, status: :created
      else
        render json: { message: import_result[:message], errors: Array(import_result.dig(:data, :errors)) }, status: :unprocessable_content
      end
    end

    private

    def import_params
      @import_params ||= params.permit(:file)
    end

    def download_params
      @download_params ||= params.permit(:start_date, :end_date, :game_types, :chunk_days)
    end

    def page_param
      raw = Integer(params[:page], exception: false)
      return 1 if raw.nil?

      raw.clamp(1, 1_000_000)
    end

    def per_page_param
      raw = Integer(params[:per_page] || params[:limit], exception: false)
      return DEFAULT_PER_PAGE if raw.nil?

      raw.clamp(1, MAX_PER_PAGE)
    end

    def total_pages(total_count, per_page)
      return 1 if total_count.zero?

      (total_count.to_f / per_page).ceil
    end

    def apply_filters(rows)
      filtered_rows = rows

      if active_filters[:game_date].present?
        parsed_date = Date.iso8601(active_filters[:game_date]) rescue nil
        filtered_rows = filtered_rows.where(game_date: parsed_date) if parsed_date
      else
        start_date = parse_iso_date(active_filters[:game_date_start])
        end_date = parse_iso_date(active_filters[:game_date_end])

        if start_date && end_date && start_date > end_date
          start_date, end_date = end_date, start_date
        end

        filtered_rows = filtered_rows.where("game_date >= ?", start_date) if start_date
        filtered_rows = filtered_rows.where("game_date <= ?", end_date) if end_date
      end

      if active_filters[:game_pk].present?
        game_pk = Integer(active_filters[:game_pk], exception: false)
        filtered_rows = filtered_rows.where(game_pk: game_pk) if game_pk
      end

      if active_filters[:pitcher].present?
        pitcher = Integer(active_filters[:pitcher], exception: false)
        filtered_rows = filtered_rows.where(pitcher: pitcher) if pitcher
      end

      if active_filters[:batter].present?
        batter = Integer(active_filters[:batter], exception: false)
        filtered_rows = filtered_rows.where(batter: batter) if batter
      end

      if active_filters[:pitch_type].present?
        filtered_rows = filtered_rows.where("LOWER(pitch_type) = ?", active_filters[:pitch_type].downcase)
      end

      if active_filters[:events].present?
        filtered_rows = filtered_rows.where("LOWER(events) = ?", active_filters[:events].downcase)
      end

      filtered_rows
    end

    def active_filters
      @active_filters ||= params.permit(:game_date, :game_date_start, :game_date_end, :game_pk, :pitcher, :batter, :pitch_type, :events).to_h.symbolize_keys
    end

    def available_events
      @available_events ||= PitchDatum.where.not(events: [nil, ""]).distinct.order(:events).pluck(:events)
    end

    def available_pitch_types
      @available_pitch_types ||= PitchDatum.where.not(pitch_type: [nil, ""]).distinct.order(:pitch_type).pluck(:pitch_type)
    end

    def data_range
      @data_range ||= {
        type: "game_date",
        start: PitchDatum.minimum(:game_date)&.iso8601,
        end: PitchDatum.maximum(:game_date)&.iso8601
      }
    end

    def parse_iso_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def serialize_pitch_datum(row, player_names = {})
      {
        id: row.id,
        game_date: row.game_date,
        game_pk: row.game_pk,
        at_bat_number: row.at_bat_number,
        pitch_number: row.pitch_number,
        pitcher: row.pitcher,
        pitcher_name: player_names[row.pitcher],
        player_name: row.player_name,
        batter: row.batter,
        batter_name: player_names[row.batter],
        pitch_type: row.pitch_type,
        release_speed: row.release_speed,
        release_spin_rate: row.release_spin_rate,
        launch_speed: row.launch_speed,
        launch_angle: row.launch_angle,
        hit_distance_sc: row.hit_distance_sc,
        balls: row.balls,
        strikes: row.strikes,
        zone: row.zone,
        inning: row.inning,
        inning_topbot: row.inning_topbot,
        description: row.description,
        events: row.events,
        pitch_name: row.pitch_name,
        raw_data: row.raw_data,
        created_at: row.created_at,
        updated_at: row.updated_at
      }
    end
  end
end
