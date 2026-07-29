class NoteRevision < ApplicationRecord
  ACTIONS = %w[created updated archived].freeze

  belongs_to :note
  belongs_to :editor, class_name: "User"

  validates :version, numericality: { only_integer: true, greater_than: 0 }
  validates :version, uniqueness: { scope: :note_id }
  validates :action, inclusion: { in: ACTIONS }
  validates :body, :note_date, presence: true
end
