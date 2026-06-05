class StatType < ApplicationRecord
  validates :name, presence: true
  validates :label, presence: true
  validates :category, presence: true
end
