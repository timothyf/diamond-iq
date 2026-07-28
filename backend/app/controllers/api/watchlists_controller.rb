module Api
  class WatchlistsController < ApplicationController
    def index
      render json: {
        data: Watchlist.includes({ need_profile: :team }, entries: { player: [ :team, :profile ] })
          .order(:name)
          .map { |watchlist| serialize_watchlist(watchlist) }
      }
    end

    def show
      render json: { data: serialize_watchlist(find_watchlist) }
    end

    def create
      watchlist = Watchlist.create!(watchlist_params)
      render json: { data: serialize_watchlist(watchlist) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      watchlist = find_watchlist
      watchlist.update!(watchlist_params)
      watchlist.entries.reload if watchlist.saved_change_to_need_profile_id?
      render json: { data: serialize_watchlist(watchlist) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def discovery
      watchlist = find_watchlist
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

    private

    def find_watchlist
      Watchlist.includes({ need_profile: :team }, entries: { player: [ :team, :profile ] }).find(params[:id])
    end

    def watchlist_params
      params.permit(:name, :description, :need_profile_id)
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
  end
end
