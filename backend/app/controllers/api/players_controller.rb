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
      player = Player.includes(:profile, :team, player_positions: :position).find(params[:id])

      render json: {
        data: serialize_player(player, include_profile: true, include_positions: true)
      }
    end

    private

    def index_params
      params.permit(:page, :per_page, :sort, filter: [:name, :first_name, :last_name, :team_id, :team_name]).to_h
    end

    def serialize_player(player, include_profile: false, include_positions: false)
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
      data[:positions] = serialize_player_positions(player.player_positions) if include_positions
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

    def serialize_player_positions(assignments)
      serialized_assignments = assignments
        .sort_by do |assignment|
          [
            assignment.season.nil? ? 0 : 1,
            -(assignment.season || 0),
            assignment.is_primary? ? 0 : 1,
            assignment.position.sort_order
          ]
        end
        .map do |assignment|
          {
            id: assignment.id,
            season: assignment.season,
            current: assignment.season.nil?,
            primary: assignment.is_primary,
            source_name: assignment.source_name,
            last_synced_at: assignment.last_synced_at,
            position: serialize_position(assignment.position)
          }
        end

      current_assignments = serialized_assignments.select { |assignment| assignment[:current] }
      primary_assignment = current_assignments.find { |assignment| assignment[:primary] }

      {
        primary: primary_assignment&.fetch(:position),
        secondary: current_assignments.reject { |assignment| assignment[:primary] }.map { |assignment| assignment[:position] },
        assignments: serialized_assignments
      }
    end

    def serialize_position(position)
      {
        id: position.id,
        mlb_code: position.mlb_code,
        abbreviation: position.abbreviation,
        name: position.name,
        position_type: position.position_type,
        sort_order: position.sort_order
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
