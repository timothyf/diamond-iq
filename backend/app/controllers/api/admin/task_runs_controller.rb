module Api
  module Admin
    class TaskRunsController < ApplicationController
      before_action :require_authenticated_user
      before_action :require_admin_user

      def index
        scope = AdminTaskRun.recent_first
        scope = scope.where(task_name: params[:task_name]) if params[:task_name].present?
        scope = scope.where(task_name: params[:task_names]) if params[:task_names].present?
        scope = scope.active if ActiveModel::Type::Boolean.new.cast(params[:active])

        render json: { data: scope.limit(10).map { |task_run| AdminTaskRunSerializer.call(reconcile_orphaned_task_run!(task_run)) } }
      end

      def show
        render json: { data: AdminTaskRunSerializer.call(reconcile_orphaned_task_run!(task_run)) }
      end

      def create
        AuditLog.record!(user: current_user, action: "import_started", record: current_user,
          metadata: { "task_name" => params[:task_name].to_s, "parameters" => params.to_unsafe_h.except("controller", "action") })
        run = case params[:task_name]
        when MlbGameDetailsTaskLauncher::TASK_NAME
          MlbGameDetailsTaskLauncher.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            mlb_game_id: params[:mlb_game_id],
            initiated_by: current_user
          )
        when PitchDataSyncTaskLauncher::TASK_NAME
          PitchDataSyncTaskLauncher.call(
            start_date: params[:start_date],
            end_date: params[:end_date],
            game_types: params[:game_types],
            chunk_days: params[:chunk_days],
            replace_existing: params[:replace_existing],
            initiated_by: current_user
          )
        when MlbRosterSyncTaskLauncher::TASK_NAME
          MlbRosterSyncTaskLauncher.call(team_scope: params[:team_scope], team_mlb_id: params[:team_mlb_id], season: params[:season], initiated_by: current_user)
        else
          AdminTaskLauncher.call(task_name: params[:task_name], params: generic_task_params, initiated_by: current_user)
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
            chunk_days: params[:chunk_days],
            replace_existing: params[:replace_existing]
          )
        when MlbRosterSyncTaskEstimate::TASK_NAME
          MlbRosterSyncTaskEstimate.call(team_scope: params[:team_scope], team_mlb_id: params[:team_mlb_id], season: params[:season])
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
        return task_run unless tracked_task_name?(task_run.task_name)

        execution_job_id = task_run.result_data.to_h["active_execution_job_id"]
        stale_heartbeat = task_run.last_heartbeat_at.blank? || task_run.last_heartbeat_at < orphaned_task_heartbeat_seconds.seconds.ago
        queue_job = execution_job_id.present? ? SolidQueue::Job.find_by(active_job_id: execution_job_id) : legacy_queue_job_for(task_run, stale_heartbeat: stale_heartbeat)
        return task_run unless queue_job

        has_claim = SolidQueue::ClaimedExecution.exists?(job_id: queue_job.id)
        return task_run if has_claim

        failed_execution = SolidQueue::FailedExecution.where(job_id: queue_job.id).order(created_at: :desc).first

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

      def tracked_task_name?(task_name)
        task_name.in?(
          AdminTaskRunner::TASKS.keys +
            AdminImportTaskLauncher::TASK_NAMES +
            [
              MlbGameDetailsTaskLauncher::TASK_NAME,
              PitchDataSyncTaskLauncher::TASK_NAME,
              MlbRosterSyncTaskLauncher::TASK_NAME
            ]
        )
      end

      def legacy_queue_job_for(task_run, stale_heartbeat:)
        return unless stale_heartbeat

        job_class = {
          MlbGameDetailsTaskLauncher::TASK_NAME => "MlbGameDetailsSyncJob",
          PitchDataSyncTaskLauncher::TASK_NAME => "PitchDataSyncJob",
          MlbRosterSyncTaskLauncher::TASK_NAME => "MlbRosterBatchSyncJob"
        }.fetch(task_run.task_name) do
          task_run.task_name.in?(AdminImportTaskLauncher::TASK_NAMES) ? "AdminImportJob" : "AdminTaskJob"
        end

        SolidQueue::Job.where(class_name: job_class).order(created_at: :desc).find do |job|
          Array(job.arguments.to_h["arguments"]).first.to_i == task_run.id
        end
      end

      def generic_task_params
        params.permit(
          :start_date,
          :end_date,
          :game_types,
          :sport_id,
          :only_missing,
          :batch_size,
          :limit,
          :mlb_ids,
          :team_scope,
          :team_mlb_id,
          :season,
          :snapshot_on,
          :mlb_game_id,
          :calculation_version
        ).to_h
      end

      def orphaned_task_heartbeat_seconds
        NineLensConfig.fetch(:operations, :game_details, :orphaned_task_heartbeat_seconds).to_i
      end
    end
  end
end
