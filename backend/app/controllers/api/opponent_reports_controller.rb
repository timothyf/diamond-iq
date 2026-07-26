module Api
  class OpponentReportsController < ApplicationController
    def index
      reports = scoped_reports.includes(:team, :opponent_team).recent_first

      render json: { data: reports.map { |report| serialize_summary(report) } }
    end

    def show
      report = OpponentReport.includes(:team, :opponent_team).find(params[:id])

      render json: { data: serialize_report(report) }
    end

    def create
      team = Team.find(params[:team_id])
      report = OpponentReportGenerator.call(team: team, season: report_params.fetch(:season, Date.current.year))

      render json: { data: serialize_report(report) }, status: :created
    rescue ArgumentError => error
      render json: { message: error.message, errors: [ error.message ] }, status: :unprocessable_content
    end

    private

    def scoped_reports
      relation = OpponentReport.all
      relation = relation.where(team_id: params[:team_id]) if params[:team_id].present?
      relation
    end

    def report_params
      params.permit(:season)
    end

    def serialize_summary(report)
      {
        id: report.id,
        title: report.title,
        season: report.season,
        series_starts_on: report.series_starts_on,
        series_ends_on: report.series_ends_on,
        generated_at: report.generated_at,
        team: serialize_team(report.team),
        opponent: serialize_team(report.opponent_team),
        probable_starter_count: Array(report.snapshot["probable_starters"]).length
      }
    end

    def serialize_report(report)
      serialize_summary(report).merge(snapshot: report.snapshot)
    end

    def serialize_team(team)
      { id: team.id, mlb_id: team.mlb_id, name: team.name, abbreviation: team.abbreviation }
    end
  end
end
