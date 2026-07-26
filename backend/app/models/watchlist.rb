class Watchlist < ApplicationRecord
  has_many :entries, class_name: "WatchlistEntry", dependent: :destroy, inverse_of: :watchlist

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end
