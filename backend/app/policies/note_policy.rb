class NotePolicy
  def initialize(user, note = nil, target: nil)
    @user = user
    @note = note
    @target = target || (note && NoteTarget.new(type: note.target_type, key: note.target_key))
  end

  def create?
    target&.writable_by?(user) || false
  end

  def read?
    target&.readable_by?(user) || false
  end

  def update?
    return false unless user&.can_write? && read?

    user.admin? || note&.author_id == user.id
  end

  alias destroy? update?

  private

  attr_reader :user, :note, :target
end
