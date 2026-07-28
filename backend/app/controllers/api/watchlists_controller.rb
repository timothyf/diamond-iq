module Api
  class WatchlistsController < ApplicationController
    before_action :require_authenticated_user

    def index
      render json: {
        data: accessible_watchlists.includes({ need_profile: :team }, entries: { player: [ :team, :profile ] })
          .order(:name)
          .map { |watchlist| serialize_watchlist(watchlist) }
      }
    end

    def show
      watchlist = find_watchlist
      require_read_access!(watchlist)
      return if performed?
      render json: { data: serialize_watchlist(watchlist) }
    end

    def create
      watchlist = current_user.owned_watchlists.build(watchlist_params)
      validate_need_profile_access!(watchlist.need_profile)
      return if performed?
      watchlist.save!
      AuditLog.record!(user: current_user, action: "created", record: watchlist, changes: watchlist.saved_changes)
      render json: { data: serialize_watchlist(watchlist) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      watchlist = find_watchlist
      require_write_access!(watchlist)
      return if performed?
      validate_need_profile_access!(NeedProfile.find_by(id: watchlist_params[:need_profile_id])) if watchlist_params[:need_profile_id].present?
      return if performed?
      watchlist.update!(watchlist_params)
      watchlist.entries.reload if watchlist.saved_change_to_need_profile_id?
      AuditLog.record!(user: current_user, action: "updated", record: watchlist, changes: watchlist.saved_changes)
      render json: { data: serialize_watchlist(watchlist) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def discovery
      watchlist = find_watchlist
      require_read_access!(watchlist)
      return if performed?
      return render json: { message: "Attach a need profile before discovering candidates." },
        status: :unprocessable_content unless watchlist.need_profile

      excluded_ids = watchlist.entries.pluck(:player_id)
      candidates = NeedProfileDiscoveryQuery.new(
        need_profile: watchlist.need_profile,
        filters: discovery_params,
        excluded_player_ids: excluded_ids
      ).result
      render json: {
        data: candidates,
        meta: {
          need_profile_id: watchlist.need_profile_id,
          result_count: candidates.length,
          filters: discovery_params.to_h
        }
      }
    end

    def audit_history
      watchlist = find_watchlist
      require_read_access!(watchlist)
      return if performed?

      ids = [ watchlist.id, *watchlist.entries.pluck(:id) ]
      logs = AuditLog.includes(:user)
        .where("(auditable_type = 'Watchlist' AND auditable_id = ?) OR (auditable_type = 'WatchlistEntry' AND auditable_id IN (?))", watchlist.id, ids)
        .order(created_at: :desc)
        .limit(100)
      render json: { data: logs.map { |log| serialize_audit_log(log) } }
    end

    private

    def find_watchlist
      accessible_watchlists.includes({ need_profile: :team }, entries: { player: [ :team, :profile ] }).find(params[:id])
    end

    def accessible_watchlists
      current_user.admin? ? Watchlist.all : Watchlist.where(owner_id: current_user.id)
    end

    def watchlist_params
      params.permit(:name, :description, :need_profile_id)
    end

    def validate_need_profile_access!(profile)
      return if profile.nil? || current_user.admin? || profile.owner_id == current_user.id

      render json: { message: "You are not authorized to use this need profile" }, status: :forbidden
    end

    def discovery_params
      params.permit(
        :name, :position_type, :bats, :throws, :age_min, :age_max,
        :team_id, :min_fit, :limit, :include_organization,
        position_types: []
      )
    end

    def serialize_watchlist(watchlist)
      {
        id: watchlist.id,
        owner: serialize_user(watchlist.owner),
        name: watchlist.name,
        description: watchlist.description,
        need_profile: serialize_need_profile(watchlist.need_profile),
        created_at: watchlist.created_at,
        updated_at: watchlist.updated_at,
        entries: watchlist.entries.sort_by { |entry| [ { "high" => 0, "medium" => 1, "low" => 2 }.fetch(entry.priority), entry.player.last_name ] }.map { |entry| serialize_entry(entry) }
      }
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

    def serialize_need_profile(profile)
      return nil unless profile

      {
        id: profile.id,
        name: profile.name,
        description: profile.description,
        criteria: profile.criteria,
        weights: profile.normalized_weights,
        team: {
          id: profile.team.id,
          name: profile.team.name,
          abbreviation: profile.team.abbreviation
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
        auditable_type: log.auditable_type,
        auditable_id: log.auditable_id,
        changes: log.change_set,
        metadata: log.metadata,
        created_at: log.created_at,
        user: serialize_user(log.user)
      }
    end
  end
end
