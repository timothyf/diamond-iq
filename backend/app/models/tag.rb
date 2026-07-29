class Tag < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  has_many :note_taggings, dependent: :destroy
  has_many :notes, through: :note_taggings

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 40 }
  validates :color, format: { with: /\A#[0-9a-f]{6}\z/i }

  before_validation :normalize_name

  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  private

  def normalize_name
    self.name = name.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
