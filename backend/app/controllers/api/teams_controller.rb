module Api
  class TeamsController < ApplicationController
    def index
      teams = Team.order(:name)

      render json: {
        data: teams.map { |team| serialize_team(team) },
        meta: { total_count: teams.size }
      }
    end

    def show
      team = Team.find(params[:id])
      snapshot = TeamProfileSnapshotQuery.new(team: team, season: params[:season]).result

      render json: { data: serialize_team(team).merge(snapshot) }
    end

    private

    def serialize_team(team)
      {
        id: team.id,
        mlb_id: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        team_name: team.team_name,
        location_name: team.location_name,
        short_name: team.short_name,
        team_code: team.team_code,
        file_code: team.file_code,
        logo_url: team.logo_url,
        created_at: team.created_at,
        updated_at: team.updated_at
      }
    end
  end
end
