class NoteTagging < ApplicationRecord
  belongs_to :note
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :note_id }
end
