module Api
  module Admin
    class TaskRunsController < ApplicationController
      ORPHANED_HEARTBEAT_SECONDS = 90

      def index
        scope = AdminTaskRun.recent_first
        scope = scope.where(task_name: params[:task_name]) if params[:task_name].present?
        scope = scope.active if ActiveModel::Type::Boolean.new.cast(params[:active])

        render json: { data: scope.limit(10).map { |task_run| AdminTaskRunSerializer.call(reconcile_orphaned_task_run!(task_run)) } }
      end

      def show
        render json: { data: AdminTaskRunSerializer.call(reconcile_orphaned_task_run!(task_run)) }
      end

      def create
        run = case params[:task_name]
        when MlbGameDetailsTaskLauncher::TASK_NAME
          MlbGameDetailsTaskLauncher.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            mlb_game_id: params[:mlb_game_id]
          )
        when PitchDataSyncTaskLauncher::TASK_NAME
          PitchDataSyncTaskLauncher.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            game_types: params[:game_types],
            chunk_days: params[:chunk_days]
          )
        else
          raise ArgumentError, "Only tracked synchronization tasks support tracked execution"
        end
        render json: { data: AdminTaskRunSerializer.call(run) }, status: :accepted
      rescue ArgumentError => error
        render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
      rescue StandardError => error
        if enqueue_error?(error)
          render json: { message: error.message, errors: [ error.message ] }, status: :service_unavailable
        else
          raise
        end
      end

      def estimate
        estimate = case params[:task_name]
        when nil, "", MlbGameDetailsTaskEstimate::TASK_NAME
          MlbGameDetailsTaskEstimate.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            mlb_game_id: params[:mlb_game_id]
          )
        when PitchDataSyncTaskEstimate::TASK_NAME
          PitchDataSyncTaskEstimate.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            game_types: params[:game_types],
            chunk_days: params[:chunk_days]
          )
        else
          raise ArgumentError, "Unsupported tracked task estimate request"
        end
        render json: { data: estimate }
      rescue ArgumentError => error
        render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
      end

      def cancel
        task_run.update!(cancel_requested_at: Time.current) if task_run.active? && !task_run.cancel_requested?
        render json: { data: AdminTaskRunSerializer.call(task_run.reload) }, status: :accepted
      end

      private

      def task_run
        @task_run ||= AdminTaskRun.find(params[:id])
      end

      def enqueue_error?(error)
        error.is_a?(SolidQueue::Job::EnqueueError) ||
          error.class.name == "ActiveJob::EnqueueError" ||
          error.class.name.end_with?("::EnqueueFailure")
      end

      def reconcile_orphaned_task_run!(task_run)
        return task_run unless task_run.active?
        return task_run unless task_run.task_name == MlbGameDetailsTaskLauncher::TASK_NAME

        execution_job_id = task_run.result_data.to_h["active_execution_job_id"]
        return task_run if execution_job_id.blank?

        queue_job = SolidQueue::Job.find_by(active_job_id: execution_job_id)
        return task_run unless queue_job

        has_claim = SolidQueue::ClaimedExecution.exists?(job_id: queue_job.id)
        return task_run if has_claim

        failed_execution = SolidQueue::FailedExecution.where(job_id: queue_job.id).order(created_at: :desc).first

        stale_heartbeat = task_run.last_heartbeat_at.blank? || task_run.last_heartbeat_at < ORPHANED_HEARTBEAT_SECONDS.seconds.ago
        return task_run if failed_execution.blank? && !stale_heartbeat

        return task_run if failed_execution.blank? && queue_job.finished_at.present?

        failure_message = failed_execution&.message.presence || "Background worker exited before this task could finish"
        task_run.with_lock do
          task_run.reload
          result_data = task_run.result_data.to_h.deep_dup
          result_data.delete("active_execution_job_id")
          errors = Array(result_data["errors"])
          errors << { "mlb_id" => nil, "message" => failure_message, "errors" => ["orphaned_execution"] }
          result_data["errors"] = errors
          task_run.update!(
            status: "failed",
            error_message: failure_message,
            finished_at: Time.current,
            result_data: result_data,
            last_heartbeat_at: Time.current
          )
        end

        task_run
      end
    end
  end
end
