class MlbRosterSyncTaskEstimate
  TASK_NAME = "mlb_roster_sync"
  def self.call(team_scope:, team_mlb_id: nil, season: Date.current.year)
    new(team_scope:, team_mlb_id:, season:).call
  end

  def initialize(team_scope:, team_mlb_id: nil, season: Date.current.year)
    @team_scope = team_scope.to_s.downcase
    @team_mlb_id = Integer(team_mlb_id, exception: false)
    @season = Integer(season, exception: false)
  end

  def call
    raise ArgumentError, "Roster scope must be one of: #{MlbRosterBatchSync::SCOPES.join(', ')}" unless MlbRosterBatchSync::SCOPES.include?(team_scope)
    raise ArgumentError, "Team MLB id is required for a specific-team roster sync" if team_scope == "team" && team_mlb_id.nil?
    MlbRosterSyncBoundary.call(season:, team_mlb_id: team_scope == "team" ? team_mlb_id : nil)

    team_count = target_team_ids.length
    timing = historical_timing
    seconds_per_team = timing.fetch(:seconds_per_team, estimate_config.fetch(:roster_seconds_per_team).to_f)
    {
      task_parameters: {
        "team_scope" => team_scope,
        "team_mlb_id" => team_scope == "team" ? team_mlb_id : nil,
        "season" => season
      },
      team_count: team_count,
      estimated_seconds: (team_count * seconds_per_team).round,
      low_estimated_seconds: (team_count * seconds_per_team * estimate_config.fetch(:roster_low_range_factor)).ceil,
      high_estimated_seconds: (team_count * seconds_per_team * estimate_config.fetch(:roster_high_range_factor)).ceil,
      seconds_per_team: seconds_per_team.round(1),
      timing_sample_team_count: timing.fetch(:team_count),
      timing_sample_run_count: timing.fetch(:run_count),
      estimate_source: timing[:seconds_per_team] ? "historical" : "conservative_default"
    }
  end

  private

  attr_reader :team_scope, :team_mlb_id, :season

  def estimate_config
    @estimate_config ||= DiamondIqConfig.fetch(:operations, :estimates)
  end

  def target_team_ids
    case team_scope
    when "all" then MlbRosterBatchSync::ALL_TEAM_IDS
    when "american", "national" then MlbRosterBatchSync::TEAM_IDS_BY_LEAGUE.fetch(team_scope)
    else [ team_mlb_id ]
    end
  end

  def historical_timing
    rows = AdminTaskRun.where(task_name: TASK_NAME, status: %w[completed cancelled])
      .where("result_data ->> 'progress_unit' = ?", "teams")
      .where.not(started_at: nil, finished_at: nil)
      .pluck(:completed_items, :failed_items, :started_at, :finished_at)
    runs = rows.filter_map do |completed, failed, started_at, finished_at|
      processed = completed + failed
      elapsed = finished_at - started_at
      [ processed, elapsed ] if processed.positive? && elapsed.positive?
    end
    total = runs.sum(&:first)
    return { team_count: 0, run_count: 0 } if total.zero?
    { seconds_per_team: runs.sum(&:last) / total, team_count: total, run_count: runs.size }
  end
end
