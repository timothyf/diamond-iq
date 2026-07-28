class WatchlistEntry < ApplicationRecord
  PRIORITIES = %w[low medium high].freeze
  STATUSES = %w[scouting active paused closed].freeze
  RECOMMENDATIONS = %w[pursue monitor pass].freeze

  belongs_to :watchlist, inverse_of: :entries
  belongs_to :player

  validates :player_id, uniqueness: { scope: :watchlist_id }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :recommendation, inclusion: { in: RECOMMENDATIONS }
  validates :fit_score, :need_score, :cost_score, :risk_score,
    numericality: { only_integer: true, in: 1..5 }, allow_nil: true

  before_validation :normalize_tags
  after_create_commit :recalculate_fit!

  def recalculate_fit!
    profile = watchlist.need_profile
    return update_columns(calculated_fit_score: nil, fit_breakdown: {}, fit_calculated_at: nil) unless profile

    result = NeedProfileFitCalculator.new(need_profile: profile, player: player).result
    update_columns(
      calculated_fit_score: result.fetch(:score),
      fit_breakdown: result.fetch(:breakdown),
      fit_calculated_at: Time.current
    )
    result
  end

  private

  def normalize_tags
    self.tags = Array(tags).filter_map { |tag| tag.to_s.strip.downcase.presence }.uniq
  end
end
