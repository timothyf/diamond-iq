module Api
  class GamesController < ApplicationController
    def index
      render_games(Game.all)
    end

    def show
      game = Game
        .includes(:schedule, :home_team, :away_team, :home_probable_pitcher, :away_probable_pitcher)
        .find(params[:id])

      render json: { data: GameSerializer.call(game) }
    end

    def upcoming
      render_games(Game.upcoming)
    end

    private

    def render_games(relation)
      query = GamesIndexQuery.new(params: game_params, relation: relation)

      render json: {
        data: query.results.map { |game| GameSerializer.call(game) },
        meta: query.metadata
      }
    end

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
  end
end
