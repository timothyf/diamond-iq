class WatchlistEntry < ApplicationRecord
  PRIORITIES = %w[low medium high].freeze
  STATUSES = %w[scouting active paused closed].freeze
  REVIEW_STATUSES = %w[
    initial_review
    analyst_review
    scout_review
    medical_review
    discuss_internally
    contact_club_or_agent
    no_longer_pursuing
  ].freeze
  REVIEW_TRANSITIONS = {
    "initial_review" => %w[analyst_review no_longer_pursuing],
    "analyst_review" => %w[initial_review scout_review no_longer_pursuing],
    "scout_review" => %w[analyst_review medical_review no_longer_pursuing],
    "medical_review" => %w[scout_review discuss_internally no_longer_pursuing],
    "discuss_internally" => %w[medical_review contact_club_or_agent no_longer_pursuing],
    "contact_club_or_agent" => %w[discuss_internally no_longer_pursuing],
    "no_longer_pursuing" => %w[initial_review]
  }.freeze
  AVAILABILITIES = %w[available potentially_available under_contract unavailable unknown].freeze
  RECOMMENDATIONS = %w[pursue monitor pass].freeze

  belongs_to :watchlist, inverse_of: :entries
  belongs_to :player
  belongs_to :candidate_owner, class_name: "User", optional: true

  validates :player_id, uniqueness: { scope: :watchlist_id }
  validates :priority, inclusion: { in: PRIORITIES }
  validates :status, inclusion: { in: STATUSES }
  validates :review_status, inclusion: { in: REVIEW_STATUSES }
  validates :availability, inclusion: { in: AVAILABILITIES }
  validates :recommendation, inclusion: { in: RECOMMENDATIONS }
  validates :estimated_cost, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :fit_score, :need_score, :cost_score, :risk_score,
    numericality: { only_integer: true, in: 1..5 }, allow_nil: true

  before_validation :normalize_tags
  validate :review_status_transition_is_allowed, on: :update
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

  def review_status_transition_is_allowed
    return unless will_save_change_to_review_status?
    return if REVIEW_TRANSITIONS.fetch(review_status_was, []).include?(review_status)

    errors.add(:review_status, "cannot move from #{review_status_was.humanize} to #{review_status.humanize}")
  end

  def normalize_tags
    self.tags = Array(tags).filter_map { |tag| tag.to_s.strip.downcase.presence }.uniq
  end
end
