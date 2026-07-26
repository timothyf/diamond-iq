module Api
  class WatchlistsController < ApplicationController
    def index
      render json: { data: Watchlist.includes(entries: { player: [ :team, :profile ] }).order(:name).map { |watchlist| serialize_watchlist(watchlist) } }
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
      render json: { data: serialize_watchlist(watchlist) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    private

    def find_watchlist
      Watchlist.includes(entries: { player: [ :team, :profile ] }).find(params[:id])
    end

    def watchlist_params
      params.permit(:name, :description)
    end

    def serialize_watchlist(watchlist)
      {
        id: watchlist.id,
        name: watchlist.name,
        description: watchlist.description,
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
