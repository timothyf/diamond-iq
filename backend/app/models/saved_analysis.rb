class SavedAnalysis < ApplicationRecord
  ANALYSIS_TYPES = %w[
    stat_explorer
    player_comparison
    team_dashboard
    acquisition_search
    player_date_range
  ].freeze
  VISIBILITIES = %w[private organization public].freeze

  belongs_to :owner, class_name: "User"

  validates :name, :reproducible_url, presence: true
  validates :name, uniqueness: { scope: [ :owner_id, :analysis_type ], case_sensitive: false }
  validates :analysis_type, inclusion: { in: ANALYSIS_TYPES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validate :reproducible_url_is_local

  scope :recent_first, -> { order(updated_at: :desc, id: :desc) }

  private

  def reproducible_url_is_local
    value = reproducible_url.to_s
    return if value.start_with?("/") && !value.start_with?("//") && !value.match?(/[\r\n]/)

    errors.add(:reproducible_url, "must be a local application URL")
  end
end
