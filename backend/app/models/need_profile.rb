class NeedProfile < ApplicationRecord
  WEIGHT_KEYS = %w[position handedness age performance].freeze
  DEFAULT_WEIGHTS = {
    "position" => 30,
    "handedness" => 15,
    "age" => 15,
    "performance" => 40
  }.freeze
  DIRECTIONS = %w[higher lower].freeze

  belongs_to :team
  has_many :watchlists, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :team_id, case_sensitive: false }
  validate :valid_criteria
  validate :valid_weights

  before_validation :normalize_configuration
  after_commit :recalculate_watchlists, on: :update
  before_destroy :clear_calculated_fits

  def normalized_weights
    DEFAULT_WEIGHTS.merge(weights.to_h.slice(*WEIGHT_KEYS))
      .transform_values { |value| Float(value, exception: false) || 0 }
  end

  private

  def normalize_configuration
    self.criteria = criteria.to_h.deep_stringify_keys
    self.weights = weights.to_h.deep_stringify_keys
  end

  def valid_criteria
    value = criteria.to_h
    invalid_positions = Array(value["position_types"]) - Position::POSITION_TYPES
    errors.add(:criteria, "contains invalid position types") if invalid_positions.any?

    invalid_bats = Array(value["bats"]) - PlayerProfile::BATTING_SIDES
    errors.add(:criteria, "contains invalid batting sides") if invalid_bats.any?

    invalid_throws = Array(value["throws"]) - PlayerProfile::THROWING_HANDS
    errors.add(:criteria, "contains invalid throwing hands") if invalid_throws.any?

    Array(value["performance"]).each do |target|
      target = target.to_h.stringify_keys
      unless target["stat_key"].present? && DIRECTIONS.include?(target["direction"]) &&
          numeric?(target["target"]) && target["target"].to_f.positive?
        errors.add(:criteria, "contains an invalid performance target")
      end
    end

    age = value["age"].to_h
    return if age.blank?

    minimum = integer_or_nil(age["min"])
    maximum = integer_or_nil(age["max"])
    errors.add(:criteria, "contains an invalid age range") if
      (age["min"].present? && minimum.nil?) ||
      (age["max"].present? && maximum.nil?) ||
      (minimum && maximum && maximum < minimum)
  end

  def valid_weights
    configured = normalized_weights
    invalid = configured.any? { |key, value| !WEIGHT_KEYS.include?(key) || !numeric?(value) || value.to_f.negative? }
    errors.add(:weights, "must contain nonnegative numeric component weights") if invalid
    errors.add(:weights, "must total more than zero") unless configured.values.sum(&:to_f).positive?
  end

  def numeric?(value)
    Float(value, exception: false).present?
  end

  def integer_or_nil(value)
    return if value.blank?

    Integer(value, exception: false)
  end

  def recalculate_watchlists
    watchlists.includes(entries: :player).find_each do |watchlist|
      watchlist.entries.find_each(&:recalculate_fit!)
    end
  end

  def clear_calculated_fits
    WatchlistEntry.where(watchlist_id: watchlist_ids).update_all(
      calculated_fit_score: nil,
      fit_breakdown: {},
      fit_calculated_at: nil
    )
  end
end
