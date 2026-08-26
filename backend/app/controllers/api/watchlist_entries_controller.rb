module Api
  class WatchlistEntriesController < ApplicationController
    before_action :require_authenticated_user

    def create
      watchlist = accessible_watchlists.find(params[:watchlist_id])
      require_write_access!(watchlist)
      return if performed?
      attributes = entry_params.to_h
      attributes["candidate_owner_id"] ||= current_user.id
      entry = watchlist.entries.create!(attributes)
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

    def transition
      entry = accessible_entries.includes(player: [ :team, :profile ]).find(params[:id])
      require_write_access!(entry.watchlist)
      return if performed?

      before = entry.review_status
      entry.update!(review_status: params.require(:review_status))
      AuditLog.record!(user: current_user, action: "review_status_changed", record: entry,
        changes: { "review_status" => [ before, entry.review_status ] })
      render json: { data: serialize_entry(entry) }
    rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => error
      message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
      render json: { message: message }, status: :unprocessable_content
    end

    def audit_history
      entry = accessible_entries.find(params[:id])
      logs = AuditLog.includes(:user)
        .where(auditable_type: "WatchlistEntry", auditable_id: entry.id)
        .order(created_at: :desc).limit(100)
      render json: { data: logs.map { |log| serialize_audit_log(log) } }
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
      params.permit(
        :player_id, :candidate_owner_id, :priority, :status, :review_status, :recommendation,
        :fit_score, :need_score, :cost_score, :risk_score, :acquisition_rationale,
        :estimated_cost, :availability, :concerns, :notes, tags: []
      )
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
        review_status: entry.review_status,
        review_statuses: WatchlistEntry::REVIEW_STATUSES,
        candidate_owner: serialize_user(entry.candidate_owner),
        acquisition_rationale: entry.acquisition_rationale,
        estimated_cost: entry.estimated_cost&.to_f,
        availability: entry.availability,
        concerns: entry.concerns,
        tags: entry.tags,
        notes: entry.notes,
        updated_at: entry.updated_at,
        player: {
          id: entry.player.id,
          mlb_id: entry.player.mlb_id,
          full_name: entry.player.full_name,
          headshot_url: entry.player.profile&.headshot_url,
          team: entry.player.display_team && { id: entry.player.display_team.id, name: entry.player.display_team.name, abbreviation: entry.player.display_team.abbreviation }
        }
      }
    end

    def serialize_user(user)
      return nil unless user

      { id: user.id, name: user.name, email: user.email, role: user.role }
    end

    def serialize_audit_log(log)
      {
        id: log.id,
        action: log.action,
        changes: log.change_set,
        created_at: log.created_at,
        user: serialize_user(log.user)
      }
    end
  end
end
