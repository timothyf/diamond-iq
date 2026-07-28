module Api
  class NeedProfilesController < ApplicationController
    def index
      profiles = NeedProfile.joins(:team).includes(:team).order("teams.name", :name)
      profiles = profiles.where(team_id: params[:team_id]) if params[:team_id].present?
      render json: { data: profiles.map { |profile| serialize(profile) } }
    end

    def show
      render json: { data: serialize(find_profile) }
    end

    def create
      profile = NeedProfile.create!(profile_params)
      render json: { data: serialize(profile) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      profile = find_profile
      profile.update!(profile_params)
      render json: { data: serialize(profile) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def destroy
      find_profile.destroy!
      head :no_content
    end

    private

    def find_profile
      NeedProfile.includes(:team).find(params[:id])
    end

    def profile_params
      params.permit(:team_id, :name, :description, :active, criteria: {}, weights: {})
    end

    def serialize(profile)
      {
        id: profile.id,
        name: profile.name,
        description: profile.description,
        active: profile.active,
        criteria: profile.criteria,
        weights: profile.normalized_weights,
        watchlist_count: profile.watchlists.count,
        team: {
          id: profile.team.id,
          name: profile.team.name,
          abbreviation: profile.team.abbreviation
        },
        created_at: profile.created_at,
        updated_at: profile.updated_at
      }
    end
  end
end
