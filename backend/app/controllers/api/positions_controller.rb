module Api
  class PositionsController < ApplicationController
    def index
      render json: {
        data: Position.ordered.map { |position| serialize_position(position) }
      }
    end

    private

    def serialize_position(position)
      {
        id: position.id,
        mlb_code: position.mlb_code,
        abbreviation: position.abbreviation,
        name: position.name,
        position_type: position.position_type,
        sort_order: position.sort_order
      }
    end
  end
end
