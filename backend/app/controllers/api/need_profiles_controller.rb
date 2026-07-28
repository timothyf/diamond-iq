module Api
  class NeedProfilesController < ApplicationController
    before_action :require_authenticated_user

    def index
      profiles = (current_user.admin? ? NeedProfile.all : NeedProfile.where(owner_id: current_user.id))
        .joins(:team).includes(:team).order("teams.name", :name)
      profiles = profiles.where(team_id: params[:team_id]) if params[:team_id].present?
      render json: { data: profiles.map { |profile| serialize(profile) } }
    end

    def show
      profile = find_profile
      require_read_access!(profile)
      return if performed?
      render json: { data: serialize(profile) }
    end

    def create
      profile = current_user.owned_need_profiles.build(profile_params)
      profile.save!
      AuditLog.record!(user: current_user, action: "created", record: profile, changes: profile.saved_changes)
      render json: { data: serialize(profile) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def update
      profile = find_profile
      require_write_access!(profile)
      return if performed?
      profile.update!(profile_params)
      AuditLog.record!(user: current_user, action: "updated", record: profile, changes: profile.saved_changes)
      render json: { data: serialize(profile) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def destroy
      profile = find_profile
      require_write_access!(profile)
      return if performed?
      AuditLog.record!(user: current_user, action: "deleted", record: profile, changes: profile.attributes)
      profile.destroy!
      head :no_content
    end

    private

    def find_profile
      scope = current_user.admin? ? NeedProfile.all : NeedProfile.where(owner_id: current_user.id)
      scope.includes(:team).find(params[:id])
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
