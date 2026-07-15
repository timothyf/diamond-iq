module Api
  module Admin
    class TasksController < ApplicationController
      def index
        render json: {
          data: AdminTaskRunner.catalog,
          meta: {
            schedule_import_range: schedule_import_range,
            schedule_date_range: schedule_date_range,
            mlb_teams: mlb_teams,
            database: database_metrics
          }
        }
      end

      def run
        result = AdminTaskRunner.call(task_name: params[:task_name], params: task_params)

        if result[:success]
          render json: serialize_result(result), status: :created
        else
          render json: serialize_result(result), status: result[:error] == :not_found ? :not_found : :unprocessable_content
        end
      end

      private

      def task_params
        params.permit(
          :start_date,
          :end_date,
          :game_types,
          :sport_id,
          :only_missing,
          :batch_size,
          :limit,
          :mlb_ids,
          :team_scope,
          :team_mlb_id,
          :season,
          :roster_type,
          :as_of
        )
      end

      def serialize_result(result)
        {
          task: result[:task],
          success: result[:success],
          message: result[:message],
          data: result[:data]
        }
      end

      def schedule_date_range
        games = Game.arel_table
        earliest_date, latest_date = Game.pick(games[:official_date].minimum, games[:official_date].maximum)

        {
          earliest_game_date: earliest_date&.iso8601,
          latest_game_date: latest_date&.iso8601
        }
      end

      def schedule_import_range
        schedules = Schedule.arel_table
        earliest_date, latest_date = Schedule.pick(schedules[:start_date].minimum, schedules[:end_date].maximum)

        {
          earliest_import_date: earliest_date&.iso8601,
          latest_import_date: latest_date&.iso8601
        }
      end

      def mlb_teams
        Team.where(mlb_id: MlbRosterBatchSync::ALL_TEAM_IDS).order(:name).map do |team|
          {
            id: team.id,
            mlb_id: team.mlb_id,
            name: team.name,
            abbreviation: team.abbreviation,
            league: MlbRosterBatchSync.league_for(team.mlb_id)
          }
        end
      end

      def database_metrics
        connection = ActiveRecord::Base.connection

        {
          environment: Rails.env,
          adapter: connection.adapter_name,
          size_bytes: database_size_bytes(connection)
        }
      end

      def database_size_bytes(connection)
        return unless connection.adapter_name.downcase.include?("postgres")

        connection.select_value("SELECT pg_database_size(current_database())").to_i
      end
    end
  end
end
