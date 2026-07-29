class Note < ApplicationRecord
  belongs_to :author, class_name: "User"
  belongs_to :last_edited_by, class_name: "User"
  has_many :note_taggings, dependent: :destroy
  has_many :tags, through: :note_taggings
  has_many :revisions, class_name: "NoteRevision", dependent: :destroy

  validates :target_type, inclusion: { in: NoteTarget::TYPES }
  validates :target_key, :body, :note_date, presence: true
  validates :body, length: { maximum: 20_000 }

  scope :active, -> { where(archived_at: nil) }
  scope :recent_first, -> { order(note_date: :desc, created_at: :desc, id: :desc) }

  def record_revision!(editor:, action:)
    revisions.create!(
      editor: editor,
      version: revisions.maximum(:version).to_i + 1,
      action: action,
      body: body,
      note_date: note_date,
      tag_names: tags.alphabetical.pluck(:name)
    )
  end
end
