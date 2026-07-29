require_dependency Rails.root.join("app/models/tag.rb").to_s

module Api
  class TagsController < ApplicationController
    skip_before_action :authenticate_unsafe_api_request, only: :create
    before_action :require_authenticated_user

    def index
      tags = Tag.alphabetical
      tags = tags.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(params[:query])}%") if params[:query].present?
      render json: { data: tags.limit(200).map { |tag| serialize(tag) } }
    end

    def create
      return render_forbidden unless current_user.can_write?

      tag = Tag.create!(tag_params.merge(created_by: current_user))
      render json: { data: serialize(tag) }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    private

    def tag_params
      params.permit(:name, :color)
    end

    def serialize(tag)
      { id: tag.id, name: tag.name, color: tag.color, created_at: tag.created_at }
    end

    def render_forbidden
      render json: { message: "You are not authorized to create tags" }, status: :forbidden
    end
  end
end
