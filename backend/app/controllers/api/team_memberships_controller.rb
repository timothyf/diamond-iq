module Api
  class TeamMembershipsController < ApplicationController
    def active_today
      query = TeamMembershipsActiveTodayQuery.new(params: query_params)

      render json: {
        data: query.results.map { |membership| serialize_membership(membership) },
        meta: query.metadata
      }
    end

    def active_range
      query = TeamMembershipsActiveRangeQuery.new(params: query_params)

      render json: {
        data: query.results.map { |membership| serialize_membership(membership) },
        meta: query.metadata
      }
    end

    def roster_status
      query = TeamMembershipsRosterStatusQuery.new(params: query_params)

      render json: {
        data: query.grouped_results.transform_values { |memberships| memberships.map { |membership| serialize_membership(membership) } },
        meta: query.metadata
      }
    end

    private

    def query_params
      params.permit(:on, :start_on, :starts_on, :end_on, :ends_on, :team_id, :player_id, :roster_status, statuses: [], filter: [:team_id, :player_id, :roster_status]).to_h
    end

    def serialize_membership(membership)
      {
        id: membership.id,
        starts_on: membership.starts_on,
        ends_on: membership.ends_on,
        roster_status: membership.roster_status,
        primary_position: membership.primary_position,
        secondary_positions: membership.secondary_positions,
        jersey_number: membership.jersey_number,
        source_name: membership.source_name,
        last_synced_at: membership.last_synced_at,
        player: {
          id: membership.player.id,
          mlb_id: membership.player.mlb_id,
          first_name: membership.player.first_name,
          last_name: membership.player.last_name,
          full_name: "#{membership.player.first_name} #{membership.player.last_name}"
        },
        team: {
          id: membership.team.id,
          mlb_id: membership.team.mlb_id,
          abbreviation: membership.team.abbreviation,
          name: membership.team.name,
          team_name: membership.team.team_name,
          location_name: membership.team.location_name,
          short_name: membership.team.short_name
        }
      }
    end
  end
end