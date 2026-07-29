require_dependency Rails.root.join("app/models/saved_analysis.rb").to_s
require_dependency Rails.root.join("app/policies/saved_analysis_policy.rb").to_s

module Api
  class SavedAnalysesController < ApplicationController
    skip_before_action :authenticate_unsafe_api_request, only: [ :create, :update, :destroy ]
    before_action :require_authenticated_user, only: [ :create, :update, :destroy ]

    def index
      analyses = policy_scope.includes(:owner).recent_first
      analyses = analyses.where(analysis_type: params[:analysis_type]) if params[:analysis_type].present?
      render json: { data: analyses.limit(100).map { |analysis| serialize(analysis) } }
    end

    def show
      analysis = SavedAnalysis.includes(:owner).find(params[:id])
      return render_forbidden unless SavedAnalysisPolicy.new(current_user, analysis).read?

      render json: { data: serialize(analysis) }
    end

    def create
      return render_forbidden unless SavedAnalysisPolicy.new(current_user).create?

      analysis = current_user.saved_analyses.create!(analysis_params)
      AuditLog.record!(user: current_user, action: "created", record: analysis, changes: analysis.saved_changes)
      render json: { data: serialize(analysis) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render_validation(error)
    end

    def update
      analysis = SavedAnalysis.includes(:owner).find(params[:id])
      return render_forbidden unless SavedAnalysisPolicy.new(current_user, analysis).update?

      analysis.update!(analysis_params)
      AuditLog.record!(user: current_user, action: "updated", record: analysis, changes: analysis.saved_changes)
      render json: { data: serialize(analysis) }
    rescue ActiveRecord::RecordInvalid => error
      render_validation(error)
    end

    def destroy
      analysis = SavedAnalysis.find(params[:id])
      return render_forbidden unless SavedAnalysisPolicy.new(current_user, analysis).destroy?

      AuditLog.record!(user: current_user, action: "deleted", record: analysis, changes: analysis.attributes)
      analysis.destroy!
      head :no_content
    end

    private

    def policy_scope
      SavedAnalysisPolicy::Scope.new(current_user).resolve
    end

    def analysis_params
      params.permit(:name, :analysis_type, :visibility, :reproducible_url, state: {})
    end

    def serialize(analysis)
      {
        id: analysis.id,
        name: analysis.name,
        analysis_type: analysis.analysis_type,
        visibility: analysis.visibility,
        state: analysis.state,
        reproducible_url: analysis.reproducible_url,
        share_url: "/saved/#{analysis.id}",
        owner: {
          id: analysis.owner.id,
          name: analysis.owner.name,
          role: analysis.owner.role
        },
        editable: SavedAnalysisPolicy.new(current_user, analysis).update?,
        created_at: analysis.created_at,
        updated_at: analysis.updated_at
      }
    end

    def render_forbidden
      render json: { message: "You are not authorized to access this saved analysis" }, status: :forbidden
    end

    def render_validation(error)
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end
  end
end
