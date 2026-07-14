module Api
  class PlayersController < ApplicationController
    def index
      query = PlayersIndexQuery.new(params: index_params)

      render json: {
        data: query.results.map { |player| serialize_player(player) },
        meta: query.metadata
      }
    end

    def show
      player = Player.includes(:profile, :team).find(params[:id])

      render json: { data: serialize_player(player, include_profile: true) }
    end

    private

    def index_params
      params.permit(:page, :per_page, :sort, filter: [:name, :first_name, :last_name, :team_id, :team_name]).to_h
    end

    def serialize_player(player, include_profile: false)
      data = {
        id: player.id,
        mlb_id: player.mlb_id,
        first_name: player.first_name,
        last_name: player.last_name,
        full_name: player.full_name,
        team: serialize_team(player.team),
        created_at: player.created_at,
        updated_at: player.updated_at
      }

      data[:profile] = serialize_profile(player.profile) if include_profile
      data
    end

    def serialize_profile(profile)
      return nil if profile.blank?

      {
        id: profile.id,
        birth_date: profile.birth_date,
        age: profile.age,
        height_inches: profile.height_inches,
        formatted_height: profile.formatted_height,
        weight_pounds: profile.weight_pounds,
        bats: profile.bats,
        throws: profile.throws,
        mlb_debut_date: profile.mlb_debut_date,
        headshot_id: profile.headshot_id,
        headshot_url: profile.headshot_url_override,
        source_name: profile.source_name,
        source_updated_at: profile.source_updated_at,
        last_synced_at: profile.last_synced_at
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
