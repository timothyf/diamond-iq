module Api
  class PlayerSeasonStatsController < ApplicationController
    before_action :set_player_season_stat, only: [:show, :update, :destroy]

    def index
      query = PlayerSeasonStatsIndexQuery.new(params: index_params)

      render json: {
        data: query.results.map { |player_season_stat| serialize_player_season_stat(player_season_stat) },
        meta: query.metadata
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

    def index_params
      params.permit(
        :page,
        :per_page,
        :sort,
        filter: [:season, :team_id, :player_id, :team_name, :player_name, :stat_type_name, :category, :min_value, :max_value]
      ).to_h
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
        player: serialize_player(player_season_stat.player),
        team: serialize_team(player_season_stat.player.team),
        stat_type: serialize_stat_type(player_season_stat.stat_type),
        created_at: player_season_stat.created_at,
        updated_at: player_season_stat.updated_at
      }
    end

    def serialize_player(player)
      {
        id: player.id,
        mlb_id: player.mlb_id,
        first_name: player.first_name,
        last_name: player.last_name,
        full_name: "#{player.first_name} #{player.last_name}"
      }
    end

    def serialize_team(team)
      {
        id: team.id,
        mlb_id: team.mlb_id,
        name: team.name,
        abbreviation: team.abbreviation,
        team_name: team.team_name,
        location_name: team.location_name,
        short_name: team.short_name
      }
    end

    def serialize_stat_type(stat_type)
      {
        id: stat_type.id,
        name: stat_type.name,
        label: stat_type.label,
        category: stat_type.category
      }
    end
  end
end
