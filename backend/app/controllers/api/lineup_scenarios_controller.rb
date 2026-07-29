module Api
  class LineupScenariosController < ApplicationController
    before_action :require_authenticated_user

    def index
      team = Team.find(params[:team_id])
      scenarios = policy_scope(team.lineup_scenarios).includes(entries: :player).order(scenario_date: :desc, created_at: :desc)
      scenarios = scenarios.where(season: params[:season]) if params[:season].present?

      render json: { data: scenarios.map { |scenario| serialize_scenario(scenario) } }
    end

    def show
      scenario = LineupScenario.includes(:team, entries: :player).find(params[:id])
      return unless authorize!(scenario, :read?)

      render json: { data: serialize_scenario(scenario) }
    end

    def create
      return unless authorize_create!

      team = Team.find(params[:team_id])
      entries = Array(scenario_params[:entries])
      violations = LineupScenarioValidator.call(team: team, entries: entries, on: parsed_scenario_date)
      if violations.any?
        render json: { message: "Lineup constraints need attention.", violations: violations }, status: :unprocessable_content
        return
      end

      scenario = LineupScenario.transaction do
        created = team.lineup_scenarios.create!(
          owner: current_user,
          season: scenario_params.fetch(:season),
          scenario_date: parsed_scenario_date,
          name: scenario_params.fetch(:name),
          notes: scenario_params[:notes],
          validated_at: Time.current,
          evaluation_inputs: evaluation_inputs
        )
        created.entries.create!(entry_attributes(entries))
        created.update!(LineupScenarioScorer.call(scenario: created, inputs: evaluation_inputs))
        created
      end
      AuditLog.record!(
        user: current_user,
        action: "created",
        record: scenario,
        changes: { "created" => [ nil, audit_snapshot(scenario.reload) ] }
      )

      render json: { data: serialize_scenario(scenario.reload) }, status: :created
    rescue ActiveRecord::RecordInvalid, KeyError => error
      message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : error.message
      render json: { message: message, errors: [ message ] }, status: :unprocessable_content
    end

    def update
      scenario = LineupScenario.includes(:team, entries: :player).find(params[:id])
      return unless authorize!(scenario, :update?)

      entries = scenario_params.key?(:entries) ? Array(scenario_params[:entries]) : serialized_entry_attributes(scenario)
      effective_date = parsed_scenario_date(default: scenario.scenario_date)
      violations = LineupScenarioValidator.call(team: scenario.team, entries: entries, on: effective_date)
      if violations.any?
        render json: { message: "Lineup constraints need attention.", violations: violations }, status: :unprocessable_content
        return
      end

      before = audit_snapshot(scenario)
      LineupScenario.transaction do
        scenario.update!(
          scenario_params.slice(:season, :name, :notes).to_h.merge(
            scenario_date: effective_date,
            evaluation_inputs: scenario_params.key?(:evaluation_inputs) ? evaluation_inputs : scenario.evaluation_inputs,
            validated_at: Time.current
          )
        )
        if scenario_params.key?(:entries)
          scenario.entries.delete_all
          scenario.entries.create!(entry_attributes(entries))
        end
        scenario.update!(LineupScenarioScorer.call(scenario: scenario, inputs: scenario.evaluation_inputs))
      end
      scenario.reload
      AuditLog.record!(
        user: current_user,
        action: "updated",
        record: scenario,
        changes: { "before" => before, "after" => audit_snapshot(scenario) }
      )

      render json: { data: serialize_scenario(scenario) }
    rescue ActiveRecord::RecordInvalid => error
      render json: { message: error.record.errors.full_messages.to_sentence }, status: :unprocessable_content
    end

    def audit_history
      scenario = LineupScenario.find(params[:id])
      return unless authorize!(scenario, :read?)

      logs = AuditLog.includes(:user)
        .where(auditable_type: "LineupScenario", auditable_id: scenario.id)
        .order(created_at: :desc)
        .limit(100)
      render json: { data: logs.map { |log| AuditLogSerializer.call(log) } }
    end

    private

    def scenario_params
      params.permit(
        :season, :scenario_date, :name, :notes,
        evaluation_inputs: [ :opponent, :opponent_strength, :park_factor, :pitcher_hand, :recent_performance, :reliability ],
        entries: [ :player_id, :batting_slot, :defensive_position ]
      )
    end

    def evaluation_inputs
      scenario_params[:evaluation_inputs]&.to_h || {}
    end

    def parsed_scenario_date(default: Date.current)
      value = scenario_params[:scenario_date].presence
      return default if value.blank?

      Date.iso8601(value.to_s)
    rescue Date::Error
      default
    end

    def entry_attributes(entries)
      entries.map { |entry| entry.to_h.symbolize_keys.slice(:player_id, :batting_slot, :defensive_position) }
    end

    def serialized_entry_attributes(scenario)
      scenario.entries.map do |entry|
        { player_id: entry.player_id, batting_slot: entry.batting_slot, defensive_position: entry.defensive_position }
      end
    end

    def audit_snapshot(scenario)
      {
        "season" => scenario.season,
        "scenario_date" => scenario.scenario_date,
        "name" => scenario.name,
        "notes" => scenario.notes,
        "evaluation_inputs" => scenario.evaluation_inputs,
        "total_score" => scenario.total_score&.to_f,
        "score_breakdown" => scenario.score_breakdown,
        "entries" => serialized_entry_attributes(scenario).map(&:stringify_keys)
      }
    end

    def policy_scope(relation)
      OwnedWorkflowPolicy::Scope.new(current_user, relation).resolve
    end

    def authorize_create!
      return true if OwnedWorkflowPolicy.new(current_user).create?

      render json: { message: "You are not authorized to create lineup scenarios" }, status: :forbidden
      false
    end

    def authorize!(scenario, action)
      return true if OwnedWorkflowPolicy.new(current_user, scenario).public_send(action)

      render json: { message: "You are not authorized to access this lineup scenario" }, status: :forbidden
      false
    end

    def serialize_scenario(scenario)
      {
        id: scenario.id,
        owner: serialize_user(scenario.owner),
        team_id: scenario.team_id,
        season: scenario.season,
        scenario_date: scenario.scenario_date,
        name: scenario.name,
        notes: scenario.notes,
        validated_at: scenario.validated_at,
        evaluation_inputs: scenario.evaluation_inputs || {},
        total_score: scenario.total_score&.to_f,
        score_breakdown: scenario.score_breakdown || {},
        entries: scenario.entries.sort_by(&:batting_slot).map do |entry|
          {
            id: entry.id,
            batting_slot: entry.batting_slot,
            defensive_position: entry.defensive_position,
            player: {
              id: entry.player.id,
              mlb_id: entry.player.mlb_id,
              full_name: entry.player.full_name,
              headshot_url: entry.player.profile&.headshot_url
            }
          }
        end
      }
    end

    def serialize_user(user)
      return nil unless user

      { id: user.id, name: user.name, email: user.email, role: user.role }
    end
  end
end
