require "rails_helper"

RSpec.describe "Api::Teams", type: :request do
  before do
    @tigers = create_team(
      mlb_id: 116,
      name: "Detroit Tigers",
      abbreviation: "DET",
      team_name: "Tigers",
      location_name: "Detroit",
      short_name: "Detroit"
    )
    @guardians = create_team(
      mlb_id: 114,
      name: "Cleveland Guardians",
      abbreviation: "CLE",
      team_name: "Guardians",
      location_name: "Cleveland",
      short_name: "Cleveland"
    )
    @schedule = create_schedule(season: Date.current.year, schedule_type: "R")
  end

  it "lists teams for the team directory" do
    get api_teams_path

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("meta", "total_count")).to eq(2)
    expect(json_body.fetch("data").map { |team| team.fetch("name") }).to eq([ "Cleveland Guardians", "Detroit Tigers" ])
    expect(json_body.dig("data", 1, "logo_url")).to eq("https://www.mlbstatic.com/team-logos/116.svg")
  end

  it "only embeds workflow summaries visible to the signed-in owner or an administrator" do
    owner = create_user(role: "coach")
    other_user = create_user(role: "scout")
    report = OpponentReport.create!(
      team: @tigers,
      opponent_team: @guardians,
      owner: owner,
      season: Date.current.year,
      series_starts_on: Date.current,
      series_ends_on: Date.current,
      title: "Private opponent report",
      generated_at: Time.current
    )
    scenario = LineupScenario.create!(
      team: @tigers,
      owner: owner,
      season: Date.current.year,
      scenario_date: Date.current,
      name: "Private lineup scenario"
    )

    get api_team_path(@tigers)
    expect(json_body.fetch("data")).to include("opponent_reports" => [], "lineup_scenarios" => [])

    get api_team_path(@tigers), headers: user_headers(other_user)
    expect(json_body.fetch("data")).to include("opponent_reports" => [], "lineup_scenarios" => [])

    get api_team_path(@tigers), headers: user_headers(owner)
    expect(json_body.dig("data", "opponent_reports").pluck("id")).to eq([ report.id ])
    expect(json_body.dig("data", "lineup_scenarios").pluck("id")).to eq([ scenario.id ])

    admin = create_user(role: "administrator")
    get api_team_path(@tigers), headers: user_headers(admin)
    expect(json_body.dig("data", "opponent_reports").pluck("id")).to eq([ report.id ])
    expect(json_body.dig("data", "lineup_scenarios").pluck("id")).to eq([ scenario.id ])
  end

  it "returns a unified roster, record, and schedule profile" do
    player = create_player(team: @tigers, attributes: { mlb_id: 680_776, first_name: "Riley", last_name: "Greene" })
    create_player_profile(player: player, attributes: { headshot_id: "680776" })
    membership = create_team_membership(
      player: player,
      team: @tigers,
      starts_on: Date.current - 30.days,
      roster_status: "active",
      jersey_number: "31",
      primary_position: "CF",
      source_status_description: "Active"
    )
    optioned_player = create_player(team: @tigers, attributes: { mlb_id: 679_529, first_name: "Spencer", last_name: "Torkelson" })
    optioned_membership = create_team_membership(
      player: optioned_player,
      team: @tigers,
      starts_on: Date.current - 20.days,
      roster_status: "minors",
      jersey_number: "20",
      primary_position: "1B",
      source_status_description: "Minors"
    )
    stale_player = create_player(team: @tigers, attributes: { mlb_id: 592_701, first_name: "Former", last_name: "Tiger" })
    create_team_membership(
      player: stale_player,
      team: @tigers,
      starts_on: Date.new(Date.current.year - 2, 12, 31),
      roster_status: "active"
    )
    current_roster = @tigers.rosters.create!(
      season: Date.current.year,
      roster_type: "40Man",
      snapshot_on: Date.current,
      source_name: MlbRosterImporter::SOURCE_NAME,
      last_synced_at: Time.current
    )
    current_roster.player_ids = [ player.id, optioned_player.id ]
    completed_game = create_game(
      schedule: @schedule,
      home_team: @tigers,
      away_team: @guardians,
      official_date: Date.current - 1.day,
      status: "final",
      home_score: 5,
      away_score: 2
    )
    upcoming_game = create_game(
      schedule: @schedule,
      home_team: @guardians,
      away_team: @tigers,
      official_date: Date.current + 1.day,
      status: "scheduled",
      venue_name: "Progressive Field"
    )
    {
      "atBats" => [ "batting", 300 ],
      "avg" => [ "batting", 0.287 ],
      "ops" => [ "batting", 0.842 ],
      "homeRuns" => [ "batting", 14 ],
      "rbi" => [ "batting", 55 ],
      "inningsPitched" => [ "pitching", 120.1 ],
      "W" => [ "pitching", 8 ],
      "ERA" => [ "pitching", 2.25 ],
      "whip" => [ "pitching", 0.99 ],
      "strikeOuts" => [ "pitching", 130 ]
    }.each do |name, (category, value)|
      stat_type = create_stat_type(name: name, label: name, category: category)
      create_player_season_stat(
        player: player,
        stat_type: stat_type,
        attributes: { team: @tigers, season: Date.current.year, value: value }
      )
    end
    TeamDailyMetric.create!(
      team: @tigers,
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 1,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        games: 1,
        wins: 1,
        losses: 0,
        ties: 0,
        runs_scored: 5,
        runs_allowed: 2,
        plate_appearances: 34,
        at_bats: 31,
        hits: 10,
        doubles: 2,
        triples: 0,
        home_runs: 1,
        stolen_bases: 2,
        walks: 3,
        strikeouts: 8,
        hit_by_pitch: 1,
        sacrifice_flies: 1,
        pitching_outs_recorded: 27,
        pitching_batters_faced: 32,
        pitching_hits_allowed: 6,
        pitching_earned_runs: 2,
        pitching_walks: 2,
        pitching_strikeouts: 9,
        pitching_saves: 1,
        pitching_quality_starts: 1
      }
    )
    TeamDailyMetric.create!(
      team: @guardians,
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 1,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        games: 1,
        wins: 0,
        losses: 1,
        ties: 0,
        runs_scored: 2,
        runs_allowed: 5,
        plate_appearances: 32,
        at_bats: 29,
        hits: 7,
        doubles: 1,
        triples: 0,
        home_runs: 0,
        stolen_bases: 0,
        walks: 2,
        strikeouts: 10,
        hit_by_pitch: 0,
        sacrifice_flies: 0,
        pitching_outs_recorded: 24,
        pitching_batters_faced: 34,
        pitching_hits_allowed: 10,
        pitching_earned_runs: 5,
        pitching_walks: 3,
        pitching_strikeouts: 8,
        pitching_saves: 0,
        pitching_quality_starts: 0
      }
    )
    PlayerBattingDaily.create!(
      player: player,
      team: @tigers,
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 4,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        games: 1,
        plate_appearances: 4,
        at_bats: 4,
        hits: 2,
        doubles: 1,
        triples: 0,
        home_runs: 0,
        walks: 0,
        strikeouts: 1
      }
    )
    PlayerPitchingDaily.create!(
      player: player,
      team: @tigers,
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 24,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        games: 1,
        games_started: 1,
        outs_recorded: 15,
        batters_faced: 24,
        pitches: 88,
        hits: 4,
        earned_runs: 1,
        walks: 1,
        strikeouts: 6
      }
    )
    BatterSplitSummary.create!(
      player: player,
      team: @tigers,
      split_type: "pitcher_hand",
      split_value: "L",
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 20,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        plate_appearances: 8,
        pitches_seen: 32,
        hits: 3,
        walks: 1,
        strikeouts: 2,
        batted_balls: 3,
        hard_hit_percentage: 33.3,
        exit_velocity_sample_size: 3,
        average_exit_velocity: 92.1
      }
    )
    PitcherSplitSummary.create!(
      player: player,
      team: @tigers,
      split_type: "batter_hand",
      split_value: "R",
      metric_date: Date.current - 1.day,
      source_start_date: Date.current - 1.day,
      source_end_date: Date.current - 1.day,
      sample_size: 20,
      calculation_version: DailyAnalyticsRefresh::CALCULATION_VERSION,
      calculated_at: Time.current,
      source_name: DailyAnalyticsRefresh::SOURCE_NAME,
      metrics: {
        batters_faced: 10,
        pitch_count: 41,
        strikeouts: 3,
        walks: 1,
        whiffs: 4,
        swings: 8,
        velocity_sample_size: 20,
        average_velocity: 95.4
      }
    )

    get api_team_path(@tigers)

    expect(response).to have_http_status(:ok)
    expect(json_body.dig("data", "name")).to eq("Detroit Tigers")
    expect(json_body.dig("data", "season")).to eq(Date.current.year)
    expect(json_body.dig("data", "record")).to include(
      "wins" => 1,
      "losses" => 0,
      "games_played" => 1,
      "runs_scored" => 5,
      "runs_allowed" => 2
    )
    serialized_membership = json_body.dig("data", "roster").find { |entry| entry.fetch("id") == membership.id }
    expect(serialized_membership).to include(
      "id" => membership.id,
      "jersey_number" => "31",
      "primary_position" => "CF"
    )
    expect(serialized_membership.dig("player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "roster_as_of")).to eq(Date.current.iso8601)
    expect(json_body.dig("data", "rosters", "forty_man").pluck("id")).to contain_exactly(membership.id, optioned_membership.id)
    expect(json_body.dig("data", "rosters", "forty_man").filter_map { |entry| entry.dig("player", "full_name") }).not_to include("Former Tiger")
    expect(json_body.dig("data", "rosters", "active").pluck("id")).to eq([ membership.id ])
    expect(json_body.dig("data", "roster_summary")).to include(
      "total" => 2,
      "active" => 1,
      "other" => 1
    )
    expect(json_body.dig("data", "recent_games", 0, "id")).to eq(completed_game.id)
    expect(json_body.dig("data", "upcoming_games", 0, "id")).to eq(upcoming_game.id)
    expect(json_body.dig("data", "team_leaders", "batting").map { |entry| entry.fetch("key") }).to eq(%w[avg ops homeRuns rbi])
    expect(json_body.dig("data", "team_leaders", "batting", 0)).to include("value" => "0.287", "abbreviation" => "AVG")
    expect(json_body.dig("data", "team_leaders", "batting", 0, "player", "full_name")).to eq("Riley Greene")
    expect(json_body.dig("data", "team_leaders", "batting", 1)).to include("value" => "0.842", "abbreviation" => "OPS")
    expect(json_body.dig("data", "team_leaders", "pitching").map { |entry| entry.fetch("key") }).to eq(%w[W ERA whip strikeOuts])
    expect(json_body.dig("data", "team_leaders", "pitching", 1)).to include("value" => "2.25", "abbreviation" => "ERA")
    expect(json_body.dig("data", "team_leaders", "pitching", 2)).to include("value" => "0.99", "abbreviation" => "WHIP")
    expect(json_body.dig("data", "source_metadata", "roster_last_synced_at")).to be_present
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "ops", "rank")).to eq(1)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "ops", "value")).to eq(0.8728)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "home_runs")).to include("rank" => 1, "value" => 1.0)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "batting_average")).to include("rank" => 1, "value" => 0.3226)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "stolen_bases")).to include("rank" => 1, "value" => 2.0)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "pitching", "strikeout_rate", "value")).to eq(0.2813)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "pitching", "walk_rate", "value")).to eq(0.0625)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "pitching", "saves")).to include("rank" => 1, "value" => 1.0)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "pitching", "strikeouts")).to include("rank" => 1, "value" => 9.0)
    expect(json_body.dig("data", "performance_dashboard", "rankings", "pitching", "quality_starts")).to include("rank" => 1, "value" => 1.0)
    expect(json_body.dig("data", "performance_dashboard", "analytics_coverage")).to include(
      "complete" => false,
      "completed_game_count" => 1,
      "complete_pitching_game_count" => 0,
      "missing_game_count" => 1
    )
    expect(json_body.dig("data", "performance_dashboard", "analytics_coverage", "missing_games", 0)).to include(
      "mlb_id" => completed_game.mlb_id,
      "matchup" => "CLE at DET"
    )
    expect(json_body.dig("data", "performance_dashboard", "recent_form", "7", "sampled_games")).to be >= 1
    expect(json_body.dig("data", "performance_dashboard", "drill_down", "players", "hitters")).not_to be_empty
    expect(json_body.dig("data", "performance_dashboard", "platoon_splits", "offense", "vs_left", "sample_size")).to eq(8.0)
  end

  it "selects a requested season" do
    old_schedule = create_schedule(
      season: 2025,
      start_date: Date.new(2025, 3, 27),
      end_date: Date.new(2025, 9, 28),
      source_key: "mlb:2025:regular"
    )
    create_game(
      schedule: old_schedule,
      home_team: @tigers,
      away_team: @guardians,
      official_date: Date.new(2025, 7, 1),
      status: "final",
      home_score: 1,
      away_score: 3
    )
    historical_player = create_player(team: @tigers, attributes: { mlb_id: 605_141, first_name: "Historical", last_name: "Tiger" })
    historical_membership = create_team_membership(
      player: historical_player,
      team: @tigers,
      starts_on: Date.new(2025, 3, 27),
      ends_on: Date.new(2025, 12, 31),
      roster_status: "active"
    )
    historical_roster = @tigers.rosters.create!(
      season: 2025,
      roster_type: "40Man",
      snapshot_on: Date.new(2025, 12, 31),
      source_name: MlbRosterImporter::SOURCE_NAME,
      last_synced_at: Time.zone.parse("2026-07-18 00:54:38")
    )
    historical_roster.player_ids = [ historical_player.id ]
    season_end_snapshot = RosterSnapshot.create!(
      team: @tigers,
      season: 2025,
      roster_type: "40Man",
      snapshot_on: Date.new(2025, 7, 1),
      source_name: MlbRosterImporter::SOURCE_NAME,
      last_synced_at: Time.zone.parse("2026-07-18 01:00:00")
    )
    season_end_snapshot.roster_snapshot_players.create!(
      player: historical_player,
      mlb_id: historical_player.mlb_id,
      full_name: historical_player.full_name,
      first_name: historical_player.first_name,
      last_name: historical_player.last_name,
      jersey_number: "25",
      position_code: "CF",
      status_code: "A",
      status_description: "Active"
    )
    historical_metric_attributes = {
      games: 1,
      plate_appearances: 4,
      at_bats: 4,
      hits: 1,
      doubles: 0,
      triples: 0,
      home_runs: 1,
      walks: 0,
      hit_by_pitch: 0,
      sacrifice_flies: 0
    }
    [
      [ Date.new(2025, 7, 1), historical_metric_attributes ],
      [ Date.current, historical_metric_attributes.merge(hits: 0, home_runs: 0) ]
    ].each do |metric_date, metrics|
      TeamDailyMetric.create!(
        team: @tigers,
        metric_date: metric_date,
        source_start_date: metric_date,
        source_end_date: metric_date,
        sample_size: 1,
        calculation_version: metric_date.year == 2025 ? DailyAnalyticsRefresh::CALCULATION_VERSION : "9.0.0",
        calculated_at: Time.current,
        source_name: DailyAnalyticsRefresh::SOURCE_NAME,
        metrics: metrics
      )
    end

    get api_team_path(@tigers), params: { season: 2025 }

    expect(json_body.dig("data", "season")).to eq(2025)
    expect(json_body.dig("data", "record", "losses")).to eq(1)
    expect(json_body.dig("data", "available_seasons")).to include(2025)
    expect(json_body.dig("data", "roster_as_of")).to eq("2025-07-01")
    expect(json_body.dig("data", "rosters", "forty_man", 0, "player", "full_name")).to eq("Historical Tiger")
    expect(json_body.dig("data", "rosters", "forty_man", 0)).to include(
      "roster_status" => "active",
      "jersey_number" => "25",
      "primary_position" => "CF"
    )
    expect(json_body.dig("data", "performance_dashboard", "rankings", "offense", "ops", "value")).to eq(1.25)
  end
end
