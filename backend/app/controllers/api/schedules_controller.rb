module Api
  class SchedulesController < ApplicationController
    def show
      schedule = Schedule.find(params[:id])
      query = GamesIndexQuery.new(params: game_params, relation: schedule.games)

      render json: {
        data: serialize_schedule(schedule, query.results),
        meta: query.metadata
      }
    end

    private

    def game_params
      params.permit(
        :page,
        :per_page,
        :team_id,
        :start_date,
        :end_date,
        :season,
        :status,
        :game_type,
        filter: [ :team_id, :start_date, :end_date, :season, :status, :game_type ]
      ).to_h
    end

    def serialize_schedule(schedule, games)
      {
        id: schedule.id,
        season: schedule.season,
        schedule_type: schedule.schedule_type,
        start_date: schedule.start_date,
        end_date: schedule.end_date,
        source_name: schedule.source_name,
        source_key: schedule.source_key,
        source_url: schedule.source_url,
        last_synced_at: schedule.last_synced_at,
        created_at: schedule.created_at,
        updated_at: schedule.updated_at,
        games: games.map { |game| GameSerializer.call(game, include_schedule: false) }
      }
    end
  end
end
