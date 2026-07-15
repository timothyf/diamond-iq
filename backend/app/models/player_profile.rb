class PlayerProfile < ApplicationRecord
  BATTING_SIDES = %w[L R S].freeze
  THROWING_HANDS = %w[L R].freeze
  MLB_HEADSHOT_URL_TEMPLATE =
    "https://img.mlbstatic.com/mlb-photos/image/upload/ar_20:23,c_fill,g_north,w_260/c_pad,b_auto:border,w_300,h_300,q_auto:best/v1/people/%<id>s/headshot/67/current".freeze

  belongs_to :player

  validates :player_id, uniqueness: true
  validates :height_inches, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :weight_pounds, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :bats, inclusion: { in: BATTING_SIDES }, allow_nil: true
  validates :throws, inclusion: { in: THROWING_HANDS }, allow_nil: true
  validates :source_name, presence: true
  validates :last_synced_at, presence: true

  def age(on: Date.current)
    return if birth_date.blank?

    years = on.year - birth_date.year
    birthday_has_occurred = on.month > birth_date.month || (on.month == birth_date.month && on.day >= birth_date.day)

    birthday_has_occurred ? years : years - 1
  end

  def formatted_height
    return if height_inches.blank?

    feet, inches = height_inches.divmod(12)
    "#{feet}' #{inches}\""
  end

  def headshot_url
    return headshot_url_override if headshot_url_override.present?
    return unless headshot_id.to_s.match?(/\A\d+\z/)

    format(MLB_HEADSHOT_URL_TEMPLATE, id: headshot_id)
  end
end
