require "rails_helper"

RSpec.describe ContextualBenchmarkRefresh, type: :service do
  let(:date) { Date.new(2026, 7, 15) }
  let(:previous_date) { date - 1.day }
  let(:team) { create_team }
  let(:batter_one) { create_player(team: team) }
  let(:batter_two) { create_player(team: team) }
  let(:starter) { create_player(team: team) }
  let(:reliever) { create_player(team: team) }

  before do
    third_base = create_position(mlb_code: "5", abbreviation: "3B", name: "Third Base", position_type: "infielder")
    create_player_position(player: batter_one, position: third_base, attributes: { is_primary: true })
    create_player_position(player: batter_two, position: third_base, attributes: { is_primary: true })

    create_batting_daily(batter_one, previous_date, plate_appearances: 4, at_bats: 4, hits: 1, doubles: 0, triples: 0, home_runs: 0, walks: 0)
    create_batting_daily(batter_one, date, plate_appearances: 5, at_bats: 4, hits: 2, doubles: 1, triples: 0, home_runs: 0, walks: 1)
    create_batting_daily(batter_two, date, plate_appearances: 4, at_bats: 4, hits: 1, doubles: 0, triples: 0, home_runs: 0, walks: 0)

    create_batter_split(batter_one, date, average_exit_velocity: 100, batted_balls: 2, hard_hit_percentage: 100, swings: 4, whiffs: 1, chase_opportunities: 4, chases: 1)
    create_batter_split(batter_two, date, average_exit_velocity: 90, batted_balls: 2, hard_hit_percentage: 0, swings: 4, whiffs: 2, chase_opportunities: 4, chases: 2)

    create_pitching_daily(starter, games: 1, games_started: 1)
    create_pitching_daily(reliever, games: 1, games_started: 0)
    create_pitcher_split(starter, average_velocity: 96, average_spin_rate: 2400, swings: 5, whiffs: 2, chase_opportunities: 4, chases: 2)
    create_pitcher_split(reliever, average_velocity: 94, average_spin_rate: 2200, swings: 5, whiffs: 1, chase_opportunities: 4, chases: 1)
    create_pitch_type(starter, "FF", 80)
    create_pitch_type(starter, "SL", 20)
    create_pitch_type(reliever, "FF", 50)
    create_pitch_type(reliever, "SL", 50)
  end

  it "builds weighted MLB, position, role, percentile, change, and sample context" do
    result = described_class.call(start_date: date, end_date: date)

    expect(result).to include(success: true)
    expect(result.dig(:data, :benchmark_count)).to be > 10
    expect(result.dig(:data, :percentile_count)).to be > result.dig(:data, :benchmark_count)

    mlb_ops = LeagueMetricBenchmark.find_by!(metric_key: "ops", peer_group_type: "mlb")
    position_ops = LeagueMetricBenchmark.find_by!(metric_key: "ops", peer_group_type: "position", peer_group_key: "3B")
    expect(mlb_ops.average_value.to_f).to be_within(0.0001).of(0.9444)
    expect(position_ops.average_value).to eq(mlb_ops.average_value)
    expect(mlb_ops).to have_attributes(sample_size: 9, player_count: 2)

    batter_percentile = PlayerMetricPercentile.find_by!(player: batter_one, league_metric_benchmark: mlb_ops)
    expect(batter_percentile.percentile.to_f).to eq(75.0)
    expect(batter_percentile.raw_value.to_f).to eq(1.35)
    expect(batter_percentile.previous_value.to_f).to eq(0.5)
    expect(batter_percentile.change_value.to_f).to eq(0.85)
    expect(batter_percentile.sample_size).to eq(5)

    exit_velocity = LeagueMetricBenchmark.find_by!(metric_key: "average_exit_velocity", peer_group_type: "mlb")
    expect(exit_velocity.average_value.to_f).to eq(95.0)
    chase = LeagueMetricBenchmark.find_by!(metric_key: "batter_chase_percentage", peer_group_type: "mlb")
    expect(chase.average_value.to_f).to eq(37.5)
    expect(PlayerMetricPercentile.find_by!(player: batter_one, league_metric_benchmark: chase).percentile.to_f).to eq(75.0)

    starter_velocity = LeagueMetricBenchmark.find_by!(metric_key: "pitcher_average_velocity", peer_group_type: "pitcher_role", peer_group_key: "starter")
    expect(starter_velocity.average_value.to_f).to eq(96.0)
    usage = LeagueMetricBenchmark.find_by!(metric_key: "pitch_usage_percentage", dimension_value: "FF", peer_group_type: "mlb")
    expect(usage.average_value.to_f).to eq(65.0)
    expect(usage.sample_size).to eq(200)
  end

  it "replaces a date range idempotently" do
    described_class.call(start_date: date, end_date: date)
    counts = [ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]

    described_class.call(start_date: date, end_date: date)

    expect([ LeagueMetricBenchmark.count, PlayerMetricPercentile.count ]).to eq(counts)
  end

  def common_daily(player, metric_date)
    {
      player: player,
      team: team,
      metric_date: metric_date,
      source_start_date: metric_date,
      source_end_date: metric_date,
      sample_size: 1,
      calculation_version: "1.0.0",
      calculated_at: Time.current,
      source_name: "spec"
    }
  end

  def create_batting_daily(player, metric_date, metrics)
    PlayerBattingDaily.create!(common_daily(player, metric_date).merge(sample_size: metrics[:plate_appearances], metrics: metrics.stringify_keys))
  end

  def create_batter_split(player, metric_date, metrics)
    BatterSplitSummary.create!(common_daily(player, metric_date).merge(
      split_type: "home_away", split_value: "home", metrics: metrics.stringify_keys
    ))
  end

  def create_pitching_daily(player, metrics)
    PlayerPitchingDaily.create!(common_daily(player, date).merge(metrics: metrics.stringify_keys))
  end

  def create_pitcher_split(player, metrics)
    PitcherSplitSummary.create!(common_daily(player, date).merge(
      split_type: "home_away", split_value: "home",
      metrics: metrics.merge(pitch_count: 10, velocity_sample_size: 10, spin_sample_size: 10).stringify_keys
    ))
  end

  def create_pitch_type(player, pitch_type, pitch_count)
    PitcherPitchTypeDaily.create!(common_daily(player, date).merge(
      pitch_type: pitch_type, sample_size: pitch_count, metrics: { "pitch_count" => pitch_count }
    ))
  end
end
