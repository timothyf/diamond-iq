class SavedAnalysisPolicy
  class Scope
    def initialize(user, relation = SavedAnalysis.all)
      @user = user
      @relation = relation
    end

    def resolve
      return relation.where(visibility: "public") unless user
      return relation.all if user.admin?

      relation.where(owner_id: user.id)
        .or(relation.where(visibility: %w[organization public]))
    end

    private

    attr_reader :user, :relation
  end

  def initialize(user, record = nil)
    @user = user
    @record = record
  end

  def create?
    user.present?
  end

  def read?
    return false unless record
    return true if record.visibility == "public"
    return false unless user

    user.admin? || record.owner_id == user.id || record.visibility == "organization"
  end

  def update?
    user.present? && (user.admin? || record&.owner_id == user.id)
  end

  alias destroy? update?

  private

  attr_reader :user, :record
end
