module Api
  class LineupScenariosController < ApplicationController
    def index
      team = Team.find(params[:team_id])
      scenarios = team.lineup_scenarios.includes(entries: :player).order(scenario_date: :desc, created_at: :desc)
      scenarios = scenarios.where(season: params[:season]) if params[:season].present?

      render json: { data: scenarios.map { |scenario| serialize_scenario(scenario) } }
    end

    def show
      scenario = LineupScenario.includes(:team, entries: :player).find(params[:id])
      render json: { data: serialize_scenario(scenario) }
    end

    def create
      team = Team.find(params[:team_id])
      entries = Array(scenario_params[:entries])
      violations = LineupScenarioValidator.call(team: team, entries: entries, on: scenario_date)
      if violations.any?
        render json: { message: "Lineup constraints need attention.", violations: violations }, status: :unprocessable_content
        return
      end

      scenario = team.lineup_scenarios.create!(
        season: scenario_params.fetch(:season),
        scenario_date: scenario_date,
        name: scenario_params.fetch(:name),
        notes: scenario_params[:notes],
        validated_at: Time.current,
        evaluation_inputs: evaluation_inputs
      )
      scenario.entries.create!(entries.map { |entry| entry.slice(:player_id, :batting_slot, :defensive_position) })
      score = LineupScenarioScorer.call(scenario: scenario, inputs: evaluation_inputs)
      scenario.update!(score)

      render json: { data: serialize_scenario(scenario.reload) }, status: :created
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

    def scenario_date
      Date.iso8601(scenario_params[:scenario_date].to_s)
    rescue Date::Error
      Date.current
    end

    def serialize_scenario(scenario)
      {
        id: scenario.id,
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
  end
end
