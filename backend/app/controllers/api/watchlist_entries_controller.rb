module Api
  class WatchlistEntriesController < ApplicationController
    def create
      watchlist = Watchlist.find(params[:watchlist_id])
      entry = watchlist.entries.create!(entry_params)
      render json: { data: serialize_entry(entry) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      entry = WatchlistEntry.includes(player: [ :team, :profile ]).find(params[:id])
      entry.update!(entry_params)
      render json: { data: serialize_entry(entry) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def destroy
      WatchlistEntry.find(params[:id]).destroy!
      head :no_content
    end

    private

    def entry_params
      params.permit(:player_id, :priority, :status, :recommendation, :fit_score, :need_score, :cost_score, :risk_score, :notes, tags: [])
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
