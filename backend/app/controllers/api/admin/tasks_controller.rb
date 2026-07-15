module Api
  module Admin
    class TasksController < ApplicationController
      def index
        render json: { data: AdminTaskRunner.catalog }
      end

      def run
        result = AdminTaskRunner.call(task_name: params[:task_name], params: task_params)

        if result[:success]
          render json: serialize_result(result), status: :created
        else
          render json: serialize_result(result), status: result[:error] == :not_found ? :not_found : :unprocessable_content
        end
      end

      private

      def task_params
        params.permit(
          :start_date,
          :end_date,
          :game_types,
          :sport_id,
          :only_missing,
          :batch_size,
          :limit,
          :mlb_ids,
          :team_mlb_id,
          :season,
          :roster_type,
          :as_of
        )
      end

      def serialize_result(result)
        {
          task: result[:task],
          success: result[:success],
          message: result[:message],
          data: result[:data]
        }
      end
    end
  end
end
