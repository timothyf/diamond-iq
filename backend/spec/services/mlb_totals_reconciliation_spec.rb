require "rails_helper"

RSpec.describe MlbTotalsReconciliation do
  let!(:team) { create_team(mlb_id: 116, name: "Detroit Tigers", abbreviation: "DET") }
  let!(:opponent) { create_team(mlb_id: 114, name: "Cleveland Guardians", abbreviation: "CLE") }
  let!(:player) { create_player(team:, attributes: { mlb_id: 682_985, first_name: "Riley", last_name: "Greene" }) }

  before do
    create_schedule(season: 2026)
    create_stats(player)
    create_game_lines
    allow(MlbTeamStatsDownloader).to receive(:call).with(season: 2026, category: "batting").and_return(
      116 => { "atBats" => 10, "runs" => 3, "hits" => 4, "homeRuns" => 1, "rbi" => 2, "baseOnBalls" => 2, "strikeOuts" => 3 }
    )
    allow(MlbTeamStatsDownloader).to receive(:call).with(season: 2026, category: "pitching").and_return(
      116 => { "inningsPitched" => "3.0", "hits" => 4, "runs" => 2, "earnedRuns" => 2, "homeRuns" => 1, "baseOnBalls" => 2, "strikeOuts" => 3 }
    )
    allow(MlbStandingsDownloader).to receive(:call).with(season: 2026).and_return(116 => { "wins" => 1, "losses" => 0 })
    allow(MlbPlayerSeasonTotalsDownloader).to receive(:call).with(mlb_id: 682_985, season: 2026, category: "batting").and_return(
      "atBats" => 10, "runs" => 3, "hits" => 4, "homeRuns" => 1, "rbi" => 2, "baseOnBalls" => 2, "strikeOuts" => 3
    )
    allow(NineLensConfig).to receive(:fetch).and_call_original
    allow(NineLensConfig).to receive(:fetch).with(:operations).and_return(
      official_reconciliation: {
        team_mlb_ids: [116],
        player_selections: [{ "mlb_id" => 682_985, "category" => "batting" }]
      }
    )
  end

  it "reports healthy official team totals, standings, and selected player totals" do
    checks = described_class.call(season: 2026).index_by { |check| check.fetch(:id) }

    expect(checks.values).to all(include(status: "healthy", affected_count: 0))
  end

  it "flags only the official total that does not reconcile" do
    allow(MlbTeamStatsDownloader).to receive(:call).with(season: 2026, category: "batting").and_return(
      116 => { "atBats" => 10, "runs" => 3, "hits" => 5, "homeRuns" => 1, "rbi" => 2, "baseOnBalls" => 2, "strikeOuts" => 3 }
    )

    check = described_class.call(season: 2026).find { |entry| entry.fetch(:id) == "official_batting_team_totals" }

    expect(check).to include(status: "warning", affected_count: 1)
    expect(check.fetch(:examples)).to include("Detroit Tigers hits: local 4.0 vs MLB 5")
  end

  it "does not double-count duplicate alias stat types" do
    alias_stat_type = StatType.find_or_create_by!(name: "RBI", category: "batting") { |entry| entry.label = "RBI" }
    create_player_season_stat(
      player:,
      stat_type: alias_stat_type,
      attributes: { team:, season: 2026, value: 2, scope_type: "team", scope_key: "DET" }
    )

    check = described_class.call(season: 2026).find { |entry| entry.fetch(:id) == "official_batting_team_totals" }

    expect(check).to include(status: "healthy", affected_count: 0)
  end

  it "does not compare a team while it has a live game today" do
    create_game(
      schedule: Schedule.first,
      official_date: ApplicationCalendar.current_date,
      status: "live",
      home_team: team,
      away_team: opponent
    )
    allow(MlbTeamStatsDownloader).to receive(:call).with(season: 2026, category: "batting").and_return(
      116 => { "atBats" => 99, "runs" => 99, "hits" => 99, "homeRuns" => 99, "rbi" => 99, "baseOnBalls" => 99, "strikeOuts" => 99 }
    )

    check = described_class.call(season: 2026).find { |entry| entry.fetch(:id) == "official_batting_team_totals" }

    expect(check).to include(status: "healthy", affected_count: 0)
  end

  def create_stats(player)
    batting = {
      "atBats" => 10, "runs" => 3, "hits" => 4, "homeRuns" => 1, "rbi" => 2, "baseOnBalls" => 2, "strikeOuts" => 3
    }
    pitching = {
      "inningsPitched" => 3.0, "hits" => 4, "runs" => 2, "earnedRuns" => 2, "homeRuns" => 1, "baseOnBalls" => 2, "strikeOuts" => 3
    }

    [ [ "batting", batting ], [ "pitching", pitching ] ].each do |category, values|
      values.each do |name, value|
        stat_type = StatType.find_or_create_by!(name:, category:) { |entry| entry.label = name }
        create_player_season_stat(player:, stat_type:, attributes: { team:, season: 2026, value:, scope_type: "team", scope_key: "DET" })
      end
    end
  end

  def create_game_lines
    game = create_game(
      schedule: Schedule.first,
      official_date: Date.new(2026, 7, 1),
      status: "final",
      home_team: team,
      away_team: opponent,
      home_score: 3,
      away_score: 2
    )
    GamePlayerBattingLine.create!(
      game:,
      player:,
      team:,
      opponent_team: opponent,
      home: true,
      at_bats: 10,
      runs: 3,
      hits: 4,
      home_runs: 1,
      runs_batted_in: 2,
      walks: 2,
      strikeouts: 3,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
    GamePlayerPitchingLine.create!(
      game:,
      player:,
      team:,
      opponent_team: opponent,
      home: true,
      outs_recorded: 9,
      hits: 4,
      runs: 2,
      earned_runs: 2,
      home_runs: 1,
      walks: 2,
      strikeouts: 3,
      source_name: "MLB Stats API",
      last_synced_at: Time.current
    )
  end
end
