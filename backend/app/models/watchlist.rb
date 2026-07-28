class Watchlist < ApplicationRecord
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :need_profile, optional: true
  has_many :entries, class_name: "WatchlistEntry", dependent: :destroy, inverse_of: :watchlist

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  after_update_commit :recalculate_entry_fits, if: :saved_change_to_need_profile_id?

  private

  def recalculate_entry_fits
    entries.find_each(&:recalculate_fit!)
  end
end
