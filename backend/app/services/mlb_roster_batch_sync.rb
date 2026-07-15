class MlbRosterBatchSync
  TEAM_IDS_BY_LEAGUE = {
    "american" => [ 108, 110, 111, 114, 116, 117, 118, 133, 136, 139, 140, 141, 142, 145, 147 ],
    "national" => [ 109, 112, 113, 115, 119, 120, 121, 134, 135, 137, 138, 143, 144, 146, 158 ]
  }.freeze
  ALL_TEAM_IDS = TEAM_IDS_BY_LEAGUE.values.flatten.sort.freeze
  SCOPES = %w[all american national team].freeze
  SUMMARY_KEYS = %i[
    membership_count
    created_player_count
    created_profile_count
    created_membership_count
    updated_membership_count
    closed_membership_count
    position_assignment_count
    duplicate_entry_count
  ].freeze

  def self.call(scope:, team_mlb_id: nil, season: Date.current.year, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current)
    new(
      scope: scope,
      team_mlb_id: team_mlb_id,
      season: season,
      roster_type: roster_type,
      as_of: as_of
    ).call
  end

  def self.league_for(team_mlb_id)
    TEAM_IDS_BY_LEAGUE.find { |_league, team_ids| team_ids.include?(team_mlb_id.to_i) }&.first
  end

  def initialize(scope:, team_mlb_id: nil, season: Date.current.year, roster_type: MlbRosterDownloader::DEFAULT_ROSTER_TYPE, as_of: Date.current)
    @scope = scope.to_s.downcase
    @team_mlb_id = Integer(team_mlb_id, exception: false)
    @season = season
    @roster_type = roster_type
    @as_of = as_of
  end

  def call
    return failure("Roster scope must be one of: #{SCOPES.join(', ')}") unless SCOPES.include?(scope)
    return failure("Team MLB id is required for a specific-team roster sync") if scope == "team" && team_mlb_id.nil?

    requested_team_ids = target_team_ids
    missing_team_ids = requested_team_ids - Team.where(mlb_id: requested_team_ids).pluck(:mlb_id)
    if missing_team_ids.any?
      return failure(
        "Roster synchronization requires all selected teams to exist locally",
        missing_team_mlb_ids: missing_team_ids
      )
    end

    summary = initial_summary(requested_team_ids)
    requested_team_ids.each { |id| synchronize_team(id, summary) }

    if summary[:failed_team_count].positive?
      return {
        success: false,
        message: failure_message(summary),
        data: summary
      }
    end

    {
      success: true,
      message: "Synchronized #{summary[:successful_team_count]} MLB team rosters",
      data: summary
    }
  end

  private

  attr_reader :as_of, :roster_type, :scope, :season, :team_mlb_id

  def target_team_ids
    case scope
    when "all"
      ALL_TEAM_IDS
    when "american", "national"
      TEAM_IDS_BY_LEAGUE.fetch(scope)
    else
      [ team_mlb_id ]
    end
  end

  def initial_summary(team_ids)
    {
      scope: scope,
      team_count: team_ids.length,
      successful_team_count: 0,
      failed_team_count: 0,
      team_mlb_ids: team_ids,
      errors: []
    }.merge(SUMMARY_KEYS.index_with(0))
  end

  def synchronize_team(id, summary)
    result = MlbRosterSync.call(
      team_mlb_id: id,
      season: season,
      roster_type: roster_type,
      as_of: as_of
    )

    unless result[:success]
      summary[:failed_team_count] += 1
      summary[:errors] << {
        team_mlb_id: id,
        message: result[:message],
        errors: Array(result.dig(:data, :errors))
      }
      return
    end

    summary[:successful_team_count] += 1
    result_data = result[:data] || {}
    SUMMARY_KEYS.each { |key| summary[key] += result_data.fetch(key, 0) }
  end

  def failure(message, data = {})
    { success: false, message: message, data: data.merge(errors: [ message ]) }
  end

  def failure_message(summary)
    message = "Synchronized #{summary[:successful_team_count]} of #{summary[:team_count]} MLB team rosters"
    first_failure = summary[:errors].first
    return message if first_failure.nil?

    details = Array(first_failure[:errors]).presence || [ first_failure[:message] ]
    "#{message}. First failure for MLB team #{first_failure[:team_mlb_id]}: #{details.join(', ')}"
  end
end
