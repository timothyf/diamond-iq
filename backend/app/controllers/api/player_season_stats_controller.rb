module Api
  class PlayerSeasonStatsController < ApplicationController
    before_action :set_player_season_stat, only: [:show, :update, :destroy]

    def index
      player_season_stats = PlayerSeasonStat.includes(:player, :stat_type).order(:season, :id)

      render json: {
        data: player_season_stats.map { |player_season_stat| serialize_player_season_stat(player_season_stat) }
      }
    end

    def show
      render json: { data: serialize_player_season_stat(@player_season_stat) }
    end

    def create
      player_season_stat = PlayerSeasonStat.new(player_season_stat_params)

      if player_season_stat.save
        render json: { data: serialize_player_season_stat(player_season_stat) }, status: :created
      else
        render json: { errors: player_season_stat.errors.full_messages }, status: :unprocessable_content
      end
    end

    def update
      if @player_season_stat.update(player_season_stat_params)
        render json: { data: serialize_player_season_stat(@player_season_stat) }
      else
        render json: { errors: @player_season_stat.errors.full_messages }, status: :unprocessable_content
      end
    end

    def destroy
      @player_season_stat.destroy
      head :no_content
    end

    private

    def set_player_season_stat
      @player_season_stat = PlayerSeasonStat.find(params[:id])
    end

    def player_season_stat_params
      params.require(:player_season_stat).permit(:player_id, :stat_type_id, :season, :value)
    end

    def serialize_player_season_stat(player_season_stat)
      {
        id: player_season_stat.id,
        player_id: player_season_stat.player_id,
        stat_type_id: player_season_stat.stat_type_id,
        season: player_season_stat.season,
        value: player_season_stat.value.to_s("F"),
        created_at: player_season_stat.created_at,
        updated_at: player_season_stat.updated_at
      }
    end
  end
end
