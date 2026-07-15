module Api
  class RosterSnapshotsController < ApplicationController
    def index
      snapshot_on = parse_date(params[:on])
      return render_error("On must be a valid ISO date") if snapshot_on.nil?

      team = find_team
      return render_error("Team is required") if team.nil?
      if params[:roster_type].present? && !RosterSnapshot::ROSTER_TYPES.include?(params[:roster_type])
        return render_error("Roster type must be one of: #{RosterSnapshot::ROSTER_TYPES.join(', ')}")
      end

      snapshots = team.roster_snapshots
        .where(snapshot_on: snapshot_on)
        .includes(:team, roster_snapshot_players: :player)
        .order(:roster_type)
      snapshots = snapshots.where(roster_type: params[:roster_type]) if params[:roster_type].present?

      render json: {
        data: snapshots.map { |snapshot| RosterSnapshotSerializer.call(snapshot) },
        meta: {
          snapshot_on: snapshot_on,
          team_id: team.id,
          team_mlb_id: team.mlb_id,
          missing_roster_types: RosterSnapshot::ROSTER_TYPES - snapshots.map(&:roster_type)
        }
      }
    end

    private

    def find_team
      return Team.find_by(id: params[:team_id]) if params[:team_id].present?
      Team.find_by(mlb_id: params[:team_mlb_id]) if params[:team_mlb_id].present?
    end

    def parse_date(value)
      Date.iso8601(value.to_s)
    rescue Date::Error
      nil
    end

    def render_error(message)
      render json: { message: message }, status: :unprocessable_content
    end
  end
end
