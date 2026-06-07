module Api
  class PlayersController < ApplicationController
    def index
      query = PlayersIndexQuery.new(params: index_params)

      render json: {
        data: query.results.map { |player| serialize_player(player) },
        meta: query.metadata
      }
    end

    private

    def index_params
      params.permit(:page, :per_page, :sort, filter: [:name, :first_name, :last_name, :team_id, :team_name]).to_h
    end

    def serialize_player(player)
      {
        id: player.id,
        first_name: player.first_name,
        last_name: player.last_name,
        team: serialize_team(player.team),
        created_at: player.created_at,
        updated_at: player.updated_at
      }
    end

    def serialize_team(team)
      {
        id: team.id,
        name: team.name,
        abbreviation: team.abbreviation,
        team_name: team.team_name,
        location_name: team.location_name,
        short_name: team.short_name,
        team_code: team.team_code,
        file_code: team.file_code
      }
    end
  end
end
