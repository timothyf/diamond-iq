module Api
  class WatchlistEntriesController < ApplicationController
    before_action :require_authenticated_user

    def create
      watchlist = accessible_watchlists.find(params[:watchlist_id])
      require_write_access!(watchlist)
      return if performed?
      entry = watchlist.entries.create!(entry_params)
      AuditLog.record!(user: current_user, action: "created", record: entry, changes: entry.saved_changes)
      render json: { data: serialize_entry(entry) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      entry = accessible_entries.includes(player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      entry.update!(entry_params)
      AuditLog.record!(user: current_user, action: "updated", record: entry, changes: entry.saved_changes)
      render json: { data: serialize_entry(entry) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def destroy
      entry = accessible_entries.find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      AuditLog.record!(user: current_user, action: "deleted", record: entry, changes: entry.attributes)
      entry.destroy!
      head :no_content
    end

    def recalculate
      entry = accessible_entries.includes(:watchlist, player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?
      return render json: { message: "Attach a need profile before calculating fit." },
        status: :unprocessable_content unless entry.watchlist.need_profile

      entry.recalculate_fit!
      AuditLog.record!(user: current_user, action: "recalculated", record: entry, changes: entry.saved_changes)
      render json: { data: serialize_entry(entry.reload) }
    end

    def alternatives
      entry = accessible_entries.includes(watchlist: :need_profile, player: [ :team, :profile, { player_positions: :position } ]).find(params[:id])
      render json: {
        data: NeedProfileAlternativesQuery.new(entry: entry, limit: params[:limit] || 5).result,
        meta: { need_profile_id: entry.watchlist.need_profile_id, source_player_id: entry.player_id }
      }
    end

    private

    def entry_params
      params.permit(:player_id, :priority, :status, :recommendation, :fit_score, :need_score, :cost_score, :risk_score, :notes, tags: [])
    end

    def accessible_watchlists
      current_user.admin? ? Watchlist.all : Watchlist.where(owner_id: current_user.id)
    end

    def accessible_entries
      current_user.admin? ? WatchlistEntry.all : WatchlistEntry.joins(:watchlist).where(watchlists: { owner_id: current_user.id })
    end

    def serialize_entry(entry)
      {
        id: entry.id,
        priority: entry.priority,
        status: entry.status,
        recommendation: entry.recommendation,
        fit_score: entry.fit_score,
        calculated_fit_score: entry.calculated_fit_score&.to_f,
        fit_breakdown: entry.fit_breakdown,
        fit_calculated_at: entry.fit_calculated_at,
        need_score: entry.need_score,
        cost_score: entry.cost_score,
        risk_score: entry.risk_score,
        tags: entry.tags,
        notes: entry.notes,
        updated_at: entry.updated_at,
        player: {
          id: entry.player.id,
          mlb_id: entry.player.mlb_id,
          full_name: entry.player.full_name,
          headshot_url: entry.player.profile&.headshot_url,
          team: entry.player.team && { id: entry.player.team.id, name: entry.player.team.name, abbreviation: entry.player.team.abbreviation }
        }
      }
    end
  end
end
