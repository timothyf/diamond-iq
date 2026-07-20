class PlayoffOddsProjection
  DEFAULT_SIMULATIONS = 5_000
  HOME_FIELD_ADVANTAGE = 0.035
  REGRESSION_RUNS = 200.0

  def initialize(divisions:, remaining_games:, simulations: DEFAULT_SIMULATIONS, seed: 0)
    @divisions = divisions
    @remaining_games = remaining_games
    @simulations = simulations
    @random = Random.new(seed)
  end

  def result
    appearances = team_ids.index_with { { division: 0, wild_card: 0, playoffs: 0 } }

    simulations.times do
      records = starting_records
      simulate_remaining_games(records)
      award_postseason_spots(records, appearances)
    end

    {
      simulations: simulations,
      remaining_games: remaining_games.length,
      model: "Monte Carlo using regressed Pythagorean strength and home-field advantage",
      teams: appearances.transform_values do |counts|
        counts.transform_values { |count| (count * 100.0 / simulations).round(1) }
      end
    }
  end

  private

  attr_reader :divisions, :remaining_games, :simulations, :random

  def team_ids
    @team_ids ||= divisions.flat_map { |division| division.fetch(:teams) }.map { |row| row.dig(:team, :id) }
  end

  def rows_by_team_id
    @rows_by_team_id ||= divisions.flat_map { |division| division.fetch(:teams) }.index_by { |row| row.dig(:team, :id) }
  end

  def starting_records
    rows_by_team_id.transform_values { |row| [ row.fetch(:wins), row.fetch(:losses) ] }
  end

  def strength(team_id)
    @strength ||= {}
    @strength[team_id] ||= begin
      row = rows_by_team_id.fetch(team_id)
      scored = row.fetch(:runs_scored) + REGRESSION_RUNS / 2.0
      allowed = row.fetch(:runs_allowed) + REGRESSION_RUNS / 2.0
      scored**1.83 / (scored**1.83 + allowed**1.83)
    end
  end

  def simulate_remaining_games(records)
    remaining_games.each do |game|
      home_id = game.home_team_id
      away_id = game.away_team_id
      next unless records.key?(home_id) && records.key?(away_id)

      home_probability = [[0.5 + strength(home_id) - strength(away_id) + HOME_FIELD_ADVANTAGE, 0.1].max, 0.9].min
      winner_id, loser_id = random.rand < home_probability ? [ home_id, away_id ] : [ away_id, home_id ]
      records[winner_id][0] += 1
      records[loser_id][1] += 1
    end
  end

  def award_postseason_spots(records, appearances)
    divisions.group_by { |division| division.fetch(:league) }.each_value do |league_divisions|
      division_winners = league_divisions.filter_map do |division|
        ids = division.fetch(:teams).map { |row| row.dig(:team, :id) }
        winner = ranked(ids, records).first
        appearances[winner][:division] += 1 if winner
        winner
      end

      wild_cards = ranked(league_divisions.flat_map { |division| division.fetch(:teams) }.map { |row| row.dig(:team, :id) } - division_winners, records).first(3)
      wild_cards.each { |team_id| appearances[team_id][:wild_card] += 1 }
      (division_winners + wild_cards).compact.each { |team_id| appearances[team_id][:playoffs] += 1 }
    end
  end

  def ranked(ids, records)
    ids.shuffle(random: random).sort_by do |team_id|
      wins, losses = records.fetch(team_id)
      [ -(wins.to_f / [ wins + losses, 1 ].max), -wins ]
    end
  end
end
