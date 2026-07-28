class NeedProfileAlternativesQuery
  DEFAULT_LIMIT = 5

  def initialize(entry:, limit: DEFAULT_LIMIT)
    @entry = entry
    @limit = (Integer(limit, exception: false) || DEFAULT_LIMIT).clamp(1, 20)
  end

  def result
    profile = entry.watchlist.need_profile
    return [] unless profile

    excluded_ids = entry.watchlist.entries.pluck(:player_id)
    candidates = NeedProfileDiscoveryQuery.new(
      need_profile: profile,
      filters: { limit: 50 },
      excluded_player_ids: excluded_ids
    ).result
    candidates.map do |candidate|
      similarity = profile_similarity(entry.player, candidate.fetch(:player))
      candidate.merge(
        similarity_score: similarity,
        alternative_score: (candidate.fetch(:calculated_fit_score) * 0.7 + similarity * 0.3).round(2)
      )
    end.sort_by { |candidate| [ -candidate.fetch(:alternative_score), candidate.dig(:player, :full_name) ] }
      .first(limit)
  end

  private

  attr_reader :entry, :limit

  def profile_similarity(target, candidate)
    target_position = target.player_positions.find(&:is_primary?)&.position || target.player_positions.first&.position
    target_age = target.profile&.age
    scores = []
    scores << (target_position&.position_type == candidate.dig(:position, :position_type) ? 100 : 35)
    scores << [ 100 - ((target_age - candidate[:age]).abs * 10), 0 ].max if target_age && candidate[:age]
    scores << (target.profile&.bats == candidate[:bats] ? 100 : 50) if target.profile&.bats && candidate[:bats]
    scores << (target.profile&.throws == candidate[:throws] ? 100 : 50) if target.profile&.throws && candidate[:throws]
    return 50 if scores.empty?

    (scores.sum / scores.length.to_f).round(2)
  end
end
