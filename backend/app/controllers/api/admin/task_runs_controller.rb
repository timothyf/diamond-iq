module Api
  module Admin
    class TaskRunsController < ApplicationController
      def index
        scope = AdminTaskRun.recent_first
        scope = scope.where(task_name: params[:task_name]) if params[:task_name].present?
        scope = scope.active if ActiveModel::Type::Boolean.new.cast(params[:active])

        render json: { data: scope.limit(10).map { |task_run| AdminTaskRunSerializer.call(task_run) } }
      end

      def show
        render json: { data: AdminTaskRunSerializer.call(task_run) }
      end

      def create
        raise ArgumentError, "Only MLB game detail synchronization supports tracked execution" unless params[:task_name] == MlbGameDetailsTaskLauncher::TASK_NAME

        run = MlbGameDetailsTaskLauncher.call(
          start_date: params[:start_date],
          end_date: params[:end_date],
          mlb_game_id: params[:mlb_game_id]
        )
        render json: { data: AdminTaskRunSerializer.call(run) }, status: :accepted
      rescue ArgumentError => error
        render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
      rescue ActiveJob::EnqueueError, SolidQueue::Job::EnqueueError => error
        render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
      end

      def cancel
        task_run.update!(cancel_requested_at: Time.current) if task_run.active? && !task_run.cancel_requested?
        render json: { data: AdminTaskRunSerializer.call(task_run.reload) }, status: :accepted
      end

      private

      def task_run
        @task_run ||= AdminTaskRun.find(params[:id])
      end
    end
  end
end
