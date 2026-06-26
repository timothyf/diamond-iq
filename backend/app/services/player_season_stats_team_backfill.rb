class PlayerSeasonStatsTeamBackfill
  DEFAULT_BATCH_SIZE = 1_000

  def self.call(dry_run: false, batch_size: DEFAULT_BATCH_SIZE, relation: PlayerSeasonStat.all)
    new(relation: relation).call(dry_run: dry_run, batch_size: batch_size)
  end

  def initialize(relation: PlayerSeasonStat.all)
    @relation = relation
  end

  def call(dry_run: false, batch_size: DEFAULT_BATCH_SIZE)
    normalized_batch_size = positive_integer(batch_size, DEFAULT_BATCH_SIZE)
    missing_scope = relation.where(team_id: nil)
    eligible_scope = missing_scope.joins(:player).where.not(players: { team_id: nil })
    missing_count = missing_scope.count
    eligible_count = eligible_scope.count

    return result(dry_run: dry_run, missing_count: missing_count, eligible_count: eligible_count, updated_count: 0) if dry_run

    updated_count = 0

    eligible_scope.in_batches(of: normalized_batch_size) do |batch|
      id_team_pairs = batch.joins(:player).pluck("player_season_stats.id", "players.team_id")

      id_team_pairs.group_by { |_id, team_id| team_id }.each do |team_id, pairs|
        updated_count += PlayerSeasonStat.where(id: pairs.map(&:first)).update_all(team_id: team_id, updated_at: Time.current)
      end
    end

    result(dry_run: false, missing_count: missing_count, eligible_count: eligible_count, updated_count: updated_count)
  end

  private

  attr_reader :relation

  def result(dry_run:, missing_count:, eligible_count:, updated_count:)
    {
      dry_run: dry_run,
      missing_count: missing_count,
      eligible_count: eligible_count,
      updated_count: updated_count,
      skipped_count: missing_count - eligible_count
    }
  end

  def positive_integer(value, fallback)
    integer = Integer(value, exception: false)
    integer&.positive? ? integer : fallback
  end
end
