class OwnedWorkflowPolicy
  class Scope
    def initialize(user, relation)
      @user = user
      @relation = relation
    end

    def resolve
      return relation.none unless user
      return relation.all if user.admin?

      relation.where(owner_id: user.id)
    end

    private

    attr_reader :user, :relation
  end

  def initialize(user, record = nil)
    @user = user
    @record = record
  end

  def create?
    user&.can_write? || false
  end

  def read?
    user.present? && (user.admin? || record&.owner_id == user.id)
  end

  def update?
    create? && (user.admin? || record&.owner_id == user.id)
  end

  private

  attr_reader :user, :record
end
